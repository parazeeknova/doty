// ==UserScript==
// @name matugen-boosts
// @description Bridges matugen color JSON to Zen Browser's per-domain Boost system. Watches the palette + per-site CSS files, and on every change updates the matching domain's Zen Boost with the latest customCSS. Replaces the Matugen JSWindowActor + per-site injection that matugen-bridge.uc.js used to do — Zen's built-in ZenBoostsChild actor handles the content-process side now.
// @author parazeeknova
// @version 1.5
// @ignorecache
// ==/UserScript==

"use strict";

const POLL_MS = 1000;

const PREFS = {
  bg: "matugen.theme.bg",
  "bg-dark": "matugen.theme.bg-dark",
  "bg-light": "matugen.theme.bg-light",
  fg: "matugen.theme.fg",
  "fg-light": "matugen.theme.fg-light",
  accent: "matugen.theme.accent",
  secondary: "matugen.theme.secondary",
  tertiary: "matugen.theme.tertiary",
};

const PREF_TO_VAR = {
  "matugen.theme.bg": "--matugen-bg",
  "matugen.theme.bg-dark": "--matugen-bg-dark",
  "matugen.theme.bg-light": "--matugen-bg-light",
  "matugen.theme.fg": "--matugen-fg",
  "matugen.theme.fg-light": "--matugen-fg-light",
  "matugen.theme.accent": "--matugen-accent",
  "matugen.theme.secondary": "--matugen-secondary",
  "matugen.theme.tertiary": "--matugen-tertiary",
};

// Per-site boost configuration.
//
// Each entry tells the bridge:
//   1. which rendered CSS file holds the userstyles for that domain
//   2. which boost knobs to set in the ZenBoostsManager entry
//
// `enableColorBoost: false` + `autoTheme: false` for sites with
// explicit userstyles — the customCSS does the work, we don't want
// the C++ tint fighting the CSS. Set `enableColorBoost: true` for
// sites where you want Zen's automatic color filter (no customCSS).
//
// `boostName` is just the human label in the Zen boost editor.
const BOOST_SITES = {
  "github.com": {
    cssFile: "matugen-userstyles-github.css",
    options: {
      boostName: "matugen github",
      enableColorBoost: false,
      autoTheme: false,
      smartInvert: false,
      brightness: 0.5,
      saturation: 0.5,
      contrast: 0.75,
      dotAngleDeg: 131.61,
      dotPos: { x: 0.76, y: 0.66 },
      dotDistance: 0.91,
      secondaryDotAngleDegDelta: 55,
      secondaryDotPos: { x: 0.5, y: 0.81 },
      changeWasMade: true,
    },
  },
};

let chromeDir = null;
let jsonFile = null;
let boostsManager = null;
let suppressBroadcast = false;
let lastJsonMtime = 0;
let lastCssMtimes = Object.create(null);
let pollTimer = null;

// ============================================================================
// Logging
// ============================================================================

let _logPath = null;
function _logFile() {
  if (_logPath) return _logPath;
  try {
    const f = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
    f.initWithPath(Services.dirsvc.get("UChrm", Ci.nsIFile).path);
    f.append("matugen-boosts.log");
    _logPath = f.path;
  } catch (e) {}
  return _logPath;
}
function _appendLog(level, msg) {
  const line = `[matugen-boosts] [${level}] ${msg}\n`;
  try {
    console.log(line);
  } catch (e) {}
  try {
    const p = _logFile();
    if (p) {
      const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
      file.initWithPath(p);
      const foStream = Cc[
        "@mozilla.org/network/file-output-stream;1"
      ].createInstance(Ci.nsIFileOutputStream);
      foStream.init(file, 0x02 | 0x08 | 0x10, 0o644, 0);
      foStream.write(line, line.length);
      foStream.flush();
      foStream.close();
    }
  } catch (e) {
    try {
      console.log("[matugen-boosts] log write failed: " + e);
    } catch (e2) {}
  }
}
const logInfo = (m) => _appendLog("INFO", m);
const logWarn = (m) => _appendLog("WARN", m);
const logError = (m) => _appendLog("ERROR", m);

logInfo("SCRIPT TOP — version 1.5 (Zen Boosts bridge)");

// ============================================================================
// File I/O
// ============================================================================

function readFile(file) {
  try {
    const fstream = Cc[
      "@mozilla.org/network/file-input-stream;1"
    ].createInstance(Ci.nsIFileInputStream);
    fstream.init(file, -1, 0, 0);
    const converter = Cc[
      "@mozilla.org/intl/converter-input-stream;1"
    ].createInstance(Ci.nsIConverterInputStream);
    converter.init(
      fstream,
      "utf-8",
      4096,
      Ci.nsIConverterInputStream.DEFAULT_REPLACEMENT_CHARACTER,
    );
    let str = "";
    let chunk = {};
    while (converter.readString(4096, chunk)) {
      str += chunk.value;
    }
    converter.close();
    fstream.close();
    return str;
  } catch (e) {
    logError(`readFile ${file.path}: ${e.message}`);
    return null;
  }
}

function readJson() {
  if (!jsonFile || !jsonFile.exists()) return null;
  const text = readFile(jsonFile);
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch (e) {
    logError(`JSON parse error: ${e.message}`);
    return null;
  }
}

// ============================================================================
// Chrome vars (for userChrome.css)
// ============================================================================

function collectValues() {
  const out = {};
  for (const [pref, varName] of Object.entries(PREF_TO_VAR)) {
    let val = "";
    try {
      val = Services.prefs.getStringPref(pref, "");
    } catch (e) {}
    if (val) out[varName] = val;
  }
  return out;
}

function applyChromeVars(values) {
  if (!values || !Object.keys(values).length) return;
  try {
    const root = document.documentElement;
    for (const [varName, val] of Object.entries(values)) {
      root.style.setProperty(varName, val);
    }
    logInfo(`Applied ${Object.keys(values).length} vars to chrome :root`);
  } catch (e) {
    logError(`applyChromeVars: ${e.message}`);
  }
}

function observePref(subject, topic, data) {
  if (topic !== "nsPref:changed") return;
  if (!data || !data.startsWith("matugen.theme.")) return;
  if (suppressBroadcast) return;
  applyChromeVars(collectValues());
}

function registerPrefObservers() {
  for (const pref of Object.keys(PREF_TO_VAR)) {
    try {
      Services.prefs.addObserver(pref, observePref);
    } catch (e) {
      logError(`addObserver ${pref}: ${e.message}`);
    }
  }
  logInfo(`Observers registered for ${Object.keys(PREF_TO_VAR).length} prefs`);
}

function applyJson(data) {
  if (!data) return;
  let count = 0;
  suppressBroadcast = true;
  try {
    for (const [jsonKey, pref] of Object.entries(PREFS)) {
      const val = data[jsonKey];
      if (typeof val === "string" && val) {
        try {
          Services.prefs.setStringPref(pref, val);
          count++;
        } catch (e) {
          logError(`setStringPref ${pref}: ${e.message}`);
        }
      }
    }
  } finally {
    suppressBroadcast = false;
  }
  if (count > 0) {
    logInfo(`Wrote ${count} prefs from matugen-vars.json`);
    applyChromeVars(collectValues());
  }
}

// ============================================================================
// Zen Boosts integration
// ============================================================================

async function loadBoostsManager() {
  try {
    const mod = await ChromeUtils.importESModule(
      "resource:///modules/zen/boosts/ZenBoostsManager.sys.mjs",
    );
    return mod.gZenBoostsManager;
  } catch (e) {
    logError(`Failed to import ZenBoostsManager: ${e.message}`);
    return null;
  }
}

function getOrCreateActiveBoost(domain) {
  if (!boostsManager) return null;

  // Try active first
  let boost = boostsManager.loadActiveBoostFromStore(domain);
  if (boost) return boost;

  // Try any existing boost for the domain
  const all = boostsManager.loadBoostsFromStore(domain);
  if (all && all.length > 0) {
    boostsManager.makeBoostActiveForDomain(domain, all[0].id);
    return boostsManager.loadActiveBoostFromStore(domain);
  }

  // Create fresh
  const newBoost = boostsManager.createNewBoost(domain);
  if (!newBoost) {
    logError(`createNewBoost returned null for ${domain}`);
    return null;
  }
  boostsManager.makeBoostActiveForDomain(domain, newBoost.id);
  return boostsManager.loadActiveBoostFromStore(domain);
}

function updateBoostForDomain(domain, css) {
  if (!boostsManager) return;
  const config = BOOST_SITES[domain];
  if (!config) return;

  const boost = getOrCreateActiveBoost(domain);
  if (!boost) {
    logError(`No boost for ${domain}, skipped update`);
    return;
  }

  const { boostData } = boost.boostEntry;
  boostData.customCSS = css;
  // Shallow-merge the options into boostData so we don't drop
  // fields the user might have set in the Zen editor.
  for (const [k, v] of Object.entries(config.options)) {
    boostData[k] = v;
  }

  try {
    boostsManager.updateBoost(boost);
    logInfo(
      `Updated boost[${domain}]: id=${boost.id} customCSS=${css.length}B enableColorBoost=${boostData.enableColorBoost}`,
    );
  } catch (e) {
    logError(`updateBoost(${domain}): ${e.message}`);
  }
}

// ============================================================================
// Poll loop — watches the palette + per-site CSS for mtime changes
// ============================================================================

function poll() {
  try {
    // 1. Palette JSON
    if (jsonFile && jsonFile.exists()) {
      const m = jsonFile.lastModifiedTime;
      if (m !== lastJsonMtime) {
        lastJsonMtime = m;
        logInfo(`matugen-vars.json mtime changed: ${m}`);
        const data = readJson();
        if (data) applyJson(data);
      }
    }

    // 2. Per-site CSS files
    if (!chromeDir || !chromeDir.exists()) return;
    for (const [domain, config] of Object.entries(BOOST_SITES)) {
      const cssFile = chromeDir.clone();
      cssFile.append(config.cssFile);
      if (!cssFile.exists()) continue;
      const m = cssFile.lastModifiedTime;
      if (m !== lastCssMtimes[domain]) {
        lastCssMtimes[domain] = m;
        const css = readFile(cssFile);
        if (css !== null) {
          logInfo(`Per-site CSS[${config.cssFile}] changed: ${css.length}B`);
          updateBoostForDomain(domain, css);
        }
      }
    }
  } catch (e) {
    logError(`Poll: ${e.message}`);
  }
}

function startPolling() {
  if (pollTimer) return;
  pollTimer = setInterval(poll, POLL_MS);
  logInfo(`Polling every ${POLL_MS}ms`);
}

// ============================================================================
// Init
// ============================================================================

async function init() {
  try {
    chromeDir = Services.dirsvc.get("UChrm", Ci.nsIFile);
    if (!chromeDir) {
      logError("Could not resolve chrome dir");
      return;
    }
    logInfo(`chrome dir: ${chromeDir.path}`);

    jsonFile = chromeDir.clone();
    jsonFile.append("matugen-vars.json");
    logInfo(`Watching: ${jsonFile.path}`);

    // Load Zen's boost manager
    boostsManager = await loadBoostsManager();
    if (!boostsManager) {
      logError("Could not load ZenBoostsManager — zen.boosts.enabled?");
      return;
    }
    logInfo("Loaded Zen Boosts Manager");

    // Pref observers
    registerPrefObservers();

    // Initial apply
    if (jsonFile.exists()) {
      const data = readJson();
      if (data) {
        lastJsonMtime = jsonFile.lastModifiedTime;
        applyJson(data);
        logInfo("Initial apply on startup");
      }
    } else {
      logInfo("matugen-vars.json not present yet, will wait for first write");
    }

    // Initial per-site CSS apply (if any CSS files exist already)
    for (const [domain, config] of Object.entries(BOOST_SITES)) {
      const cssFile = chromeDir.clone();
      cssFile.append(config.cssFile);
      if (cssFile.exists()) {
        lastCssMtimes[domain] = cssFile.lastModifiedTime;
        const css = readFile(cssFile);
        if (css !== null) {
          logInfo(`Loaded userstyles[${config.cssFile}]: ${css.length}B`);
          updateBoostForDomain(domain, css);
        }
      } else {
        logInfo(`No ${config.cssFile} yet, will wait`);
      }
    }

    startPolling();
  } catch (e) {
    logError(`Init: ${e.message}\n${e.stack || ""}`);
  }
}

init();
