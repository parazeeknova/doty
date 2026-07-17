// ==UserScript==
// @name matugen-bridge
// @description Bridges matugen color JSON to Firefox CSS variables (chrome + content via JSWindowActor), and pushes per-site userstyles CSS to Zen's per-domain Boost system. The actor handles global :root vars on every page (since userContent.css is unreliable on Zen 1.20.1b); Zen's built-in ZenBoostsChild actor handles per-site customCSS via AGENT_SHEET registration.
// @author parazeeknova
// @version 1.7
// @ignorecache
// ==/UserScript==

// Append a string to the log file using lazy OS.File to avoid the
// complexity of nsIFileOutputStream (which has been flaky — the
// log file gets created but writes never persist). This opens the
// file lazily and writes synchronously.
let _logPath = null;
function _logFile() {
  if (_logPath) return _logPath;
  try {
    const f = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
    f.initWithPath(Services.dirsvc.get("UChrm", Ci.nsIFile).path);
    f.append("matugen-bridge.log");
    _logPath = f.path;
  } catch (e) {}
  return _logPath;
}
function _appendLog(level, msg) {
  const line = `[matugen-bridge] [${level}] ${msg}\n`;
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
      // PR_WRITE_ONLY | PR_CREATE_FILE | PR_APPEND
      foStream.init(file, 0x02 | 0x08 | 0x10, 0o644, 0);
      foStream.write(line, line.length);
      foStream.flush();
      foStream.close();
    }
  } catch (e) {
    try {
      console.log("[matugen-bridge] log write failed: " + e);
    } catch (e2) {}
  }
}
function logInfo(msg) {
  _appendLog("INFO", msg);
}
function logWarn(msg) {
  _appendLog("WARN", msg);
}
function logError(msg) {
  _appendLog("ERROR", msg);
}

logInfo("SCRIPT TOP — version 1.7");

("use strict");

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

const ACTOR_NAME = "Matugen";
const ACTOR_PARENT_URI =
  "chrome://userscripts/content/Matugen/MatugenParent.sys.mjs";
const ACTOR_CHILD_URI =
  "chrome://userscripts/content/Matugen/MatugenChild.sys.mjs";
const USERSTYLES_PREFIX = "matugen-userstyles-";
const USERSTYLES_GLOBAL = "matugen-userstyles.css";

// Map hostname suffix -> file suffix (after matugen-userstyles-).
// github.com, gist.github.com, docs.github.com, etc. all match
// suffix "github". Add more sites here as we author more templates.
const HOST_TO_FILE = {
  "github.com": "github",
  "gist.github.com": "github",
  "docs.github.com": "github",
  "raw.githubusercontent.com": "github",
};

// Per-site boost config — sibling of HOST_TO_FILE. When a hostname
// matches a suffix here, the bridge also pushes the CSS into a
// Zen Boost's customCSS field. Zen's ZenBoostsChild actor then
// registers it as an AGENT_SHEET (survives Fission, hot-reloadable
// via the 'zen-boosts-update' observer event).
//
// `enableColorBoost: false` because we have explicit CSS — the
// C++ tint layer would fight the customCSS. Zen's own editor can
// override these per-site if a user wants the tint instead.
let boostsManager = null;
const BOOST_SITES = {};

let chromeDir = null;
let jsonFile = null;
let userstylesDir = null;
let userstyles = {
  // global: { css, mtime, path }
  // github: { css, mtime, path }
};
let lastMtime = 0;
let pollTimer = null;
let universalPollTimer = null;
let actorReady = false;
let customWebThemeEnabled = true;
let lastWebThemeStateMtime = 0;
let suppressBroadcast = false;

function readWebThemeState() {
  try {
    const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
    const homeDir = Services.dirsvc.get("Home", Ci.nsIFile).path;
    file.initWithPath(homeDir + "/.cache/quickshell/custom_web_theme_state");
    if (!file.exists()) return { enabled: true, mtime: 0 };
    const text = readFile(file);
    return {
      enabled: text.trim() !== "false",
      mtime: file.lastModifiedTime,
    };
  } catch (e) {
    return { enabled: true, mtime: 0 };
  }
}

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
    return null;
  }
}

function loadUserstylesFor(name, file) {
  if (!file || !file.exists()) {
    userstyles[name] = { css: "", mtime: 0, path: file ? file.path : null };
    return;
  }
  const css = readFile(file);
  if (css === null) {
    userstyles[name] = { css: "", mtime: 0, path: file.path };
    return;
  }
  const oldEntry = userstyles[name];
  const oldCss = oldEntry ? oldEntry.css : null;
  userstyles[name] = { css, mtime: file.lastModifiedTime, path: file.path };
  if (oldCss === null || oldCss !== css) {
    logInfo(
      `Loaded userstyles[${name}]: ${css.length} bytes from ${file.path}`,
    );
    // Sync to Zen Boosts if configured
    for (const [domain, config] of Object.entries(BOOST_SITES)) {
      const fileSuffix = config.cssFile.slice(USERSTYLES_PREFIX.length, -4);
      if (fileSuffix === name) {
        logInfo(`Syncing boost for ${domain} due to userstyles change`);
        try {
          syncBoostForDomain(domain, config, css);
        } catch (e) {
          logError(`loadUserstylesFor syncBoost[${domain}]: ${e.message}`);
        }
      }
    }
  }
}

function loadAllUserstyles() {
  if (!userstylesDir || !userstylesDir.exists()) return;
  // global
  const globalFile = userstylesDir.clone();
  globalFile.append(USERSTYLES_GLOBAL);
  loadUserstylesFor("global", globalFile);
  // per-host (any matugen-userstyles-<name>.css file)
  let found = 0;
  try {
    const entries = userstylesDir.directoryEntries;
    while (entries.hasMoreElements()) {
      const raw = entries.getNext();
      try {
        const f = raw.QueryInterface(Ci.nsIFile);
        const fname = f.leafName;
        if (!fname || !fname.startsWith(USERSTYLES_PREFIX)) continue;
        if (fname === USERSTYLES_GLOBAL) continue;
        if (fname.endsWith(".disabled")) continue;
        if (!f.isFile()) continue;
        const suffix = fname.slice(USERSTYLES_PREFIX.length, -4); // strip prefix and .css
        loadUserstylesFor(suffix, f);
        // Side-effect: if there's a BOOST_SITES entry for this file,
        // push the freshly-loaded CSS into a Zen Boost's customCSS
        // field so Zen's built-in actor takes over injection.
        for (const [domain, config] of Object.entries(BOOST_SITES)) {
          if (
            config.cssFile === fname &&
            userstyles[suffix] &&
            userstyles[suffix].css
          ) {
            syncBoostForDomain(domain, config, userstyles[suffix].css);
          }
        }
        found++;
      } catch (e) {
        logError(`scan entry error: ${e.message}`);
      }
    }
    if (found > 0)
      logInfo(
        `Scanned userstyles dir: ${found} per-site file(s) (${Object.keys(
          userstyles,
        )
          .filter((k) => k !== "global")
          .join(", ")})`,
      );
  } catch (e) {
    logError(`scan userstyles dir: ${e.message}`);
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
  let boost = boostsManager.loadActiveBoostFromStore(domain);
  if (boost) return boost;
  const all = boostsManager.loadBoostsFromStore(domain);
  if (all && all.length > 0) {
    boostsManager.makeBoostActiveForDomain(domain, all[0].id);
    return boostsManager.loadActiveBoostFromStore(domain);
  }
  const newBoost = boostsManager.createNewBoost(domain);
  if (!newBoost) return null;
  boostsManager.makeBoostActiveForDomain(domain, newBoost.id);
  return boostsManager.loadActiveBoostFromStore(domain);
}

function syncBoostForDomain(domain, config, css) {
  if (!boostsManager) return;
  const boost = getOrCreateActiveBoost(domain);
  if (!boost) {
    logError(`No boost for ${domain}, skipped sync`);
    return;
  }
  const { boostData } = boost.boostEntry;
  boostData.customCSS = css;
  for (const [k, v] of Object.entries(config.options)) {
    boostData[k] = v;
  }
  try {
    boostsManager.updateBoost(boost);
    logInfo(`Synced boost[${domain}]: id=${boost.id} customCSS=${css.length}B`);
  } catch (e) {
    logError(`updateBoost(${domain}): ${e.message}`);
  }
}

// Default boost knobs applied to any visited domain that doesn't
// already have a boost with customCSS. Tints every color toward
// the active Zen workspace's gradient color (which is set from the
// wallpaper). This is the "every site gets tinted" layer — the
// whole point of Zen Boosts.
const UNIVERSAL_BOOST_OPTIONS = {
  boostName: "matugen universal",
  enableColorBoost: true,
  autoTheme: false, // force manual HSL mapping to bypass Zen autoTheme hue bug
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
};

let universalBoostedDomains = new Set();
let lastSyncedAccent = null;

// Iterate over all open browser tabs. For any tab whose hostname
// doesn't yet have a registered boost, create one with the
// universal tint knobs. This is the universal "every site gets
// tinted" layer. Returns the count of new boosts created.
function syncUniversalBoosts() {
  if (!boostsManager) {
    logInfo(`Universal sync skipped: no boostsManager`);
    return 0;
  }
  let created = 0;
  let windows = 0;
  let tabs = 0;
  let httpTabs = 0;
  let skippedNoHost = 0;
  let skippedAlreadyBoosted = 0;
  let skippedPerSite = 0;
  let skippedRegistered = 0;
  try {
    const wm = Services.wm.getEnumerator("navigator:browser");
    while (wm.hasMoreElements()) {
      windows++;
      const win = wm.getNext();
      if (!win.gBrowser) continue;
      for (const tab of win.gBrowser.tabs) {
        tabs++;
        try {
          const browser = tab.linkedBrowser;
          if (!browser) continue;
          // browser.currentURI is normally safe to read, but some
          // tabs (lazy-loading, preloaded, about:blank with no
          // principal) can have a URI whose .host getter throws
          // NS_ERROR_FAILURE. We bail out cleanly in that case.
          let uri;
          try {
            uri = browser.currentURI;
          } catch (_) {
            skippedNoHost++;
            continue;
          }
          if (!uri) {
            skippedNoHost++;
            continue;
          }
          let host;
          try {
            host = uri.host;
          } catch (_) {
            skippedNoHost++;
            continue;
          }
          if (!host) {
            skippedNoHost++;
            continue;
          }
          // Only HTTP/HTTPS — Zen restricts boost schemes to these
          // (see canBoostSite() in ZenBoostsManager).
          if (!uri.schemeIs("http") && !uri.schemeIs("https")) {
            skippedNoHost++;
            continue;
          }
          httpTabs++;
          const domain = host;
          if (universalBoostedDomains.has(domain)) {
            skippedAlreadyBoosted++;
            continue;
          }
          // Skip domains that have an explicit per-site boost
          // entry in BOOST_SITES — BUT only if their userstyles
          // file actually exists on disk. If the file is missing
          // (e.g. user renamed the template to .disabled), fall
          // through to the universal tint so the domain doesn't
          // end up unthemed.
          if (BOOST_SITES[domain]) {
            const cfg = BOOST_SITES[domain];
            const f = userstylesDir.clone();
            f.append(cfg.cssFile);
            if (f.exists() && !cfg.cssFile.endsWith(".disabled")) {
              universalBoostedDomains.add(domain);
              skippedPerSite++;
              continue;
            }
            // Fall through: per-site CSS is gone, use universal.
            logInfo(
              `Per-site CSS for ${domain} missing, falling back to universal tint`,
            );
          }
          // Skip if Zen already has a registered boost for this
          // domain (user might have created one in the Zen UI).
          if (boostsManager.registeredBoostForDomain(domain)) {
            universalBoostedDomains.add(domain);
            skippedRegistered++;
            continue;
          }
          // Create a new boost with the universal tint knobs.
          // getOrCreateActiveBoost handles both the "no entry" case
          // (creates + activates) and the "existing entry, not active"
          // case (activates an existing one).
          const boost = getOrCreateActiveBoost(domain);
          if (!boost) {
            logError(`getOrCreateActiveBoost returned null for ${domain}`);
            continue;
          }
          const { boostData } = boost.boostEntry;
          boostData.customCSS = "";
          for (const [k, v] of Object.entries(UNIVERSAL_BOOST_OPTIONS)) {
            boostData[k] = v;
          }
          boostsManager.updateBoost(boost);
          universalBoostedDomains.add(domain);
          created++;
        } catch (e) {
          logError(`universal sync tab: ${e.message}`);
        }
      }
    }
  } catch (e) {
    logError(`syncUniversalBoosts: ${e.message}`);
  }
  logInfo(
    `Universal sync: ${windows}w/${tabs}t (http=${httpTabs}, noHost=${skippedNoHost}, perSite=${skippedPerSite}, registered=${skippedRegistered}, already=${skippedAlreadyBoosted}) created=${created}`,
  );
  // Always re-run the workspace sync after the universal sync —
  // this picks up the HSL path for any domains we now know about
  // (whether just created or pre-existing in Zen's storage).
  if (universalBoostedDomains.size > 0) {
    try {
      const data = readJson();
      if (data) syncWorkspaceTheme(data, created > 0 || lastSyncedAccent === null);
    } catch (e) {
      logError(`post-universal sync: ${e.message}`);
    }
  }
  return created;
}

function getUserstylesForHostname(hostname) {
  const out = [];
  if (userstyles.global && userstyles.global.css) {
    out.push(userstyles.global.css);
  }
  if (customWebThemeEnabled) {
    const parts = (hostname || "").split(".");
    let suffix = null;
    for (let i = 0; i < parts.length; i++) {
      const candidate = parts.slice(i).join(".");
      if (HOST_TO_FILE[candidate]) {
        suffix = HOST_TO_FILE[candidate];
        break;
      }
    }
    if (suffix && userstyles[suffix] && userstyles[suffix].css) {
      out.push(userstyles[suffix].css);
    }
  }
  return out.join("\n/* ---- per-site overlay ---- */\n");
}

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

function broadcastToActors(values) {
  if (!values || !Object.keys(values).length) return;
  if (!actorReady) return;
  let total = 0,
    sent = 0,
    skipped = 0;
  try {
    const windows = Services.wm.getEnumerator("navigator:browser");
    while (windows.hasMoreElements()) {
      const win = windows.getNext();
      if (!win.gBrowser) continue;
      for (const tab of win.gBrowser.tabs) {
        total++;
        try {
          const browser = tab.linkedBrowser;
          if (!browser) {
            skipped++;
            continue;
          }
          const bc = browser.browsingContext;
          if (!bc) {
            skipped++;
            continue;
          }
          const wg = bc.currentWindowGlobal;
          if (!wg) {
            skipped++;
            continue;
          }
          const actor = wg.getActor(ACTOR_NAME);
          if (!actor) {
            skipped++;
            continue;
          }
          actor.sendAsyncMessage("Matugen:ApplyVars", values);
          sent++;
        } catch (e) {
          skipped++;
        }
      }
    }
    logInfo(
      `Broadcast vars to ${sent}/${total} tab actors (skipped=${skipped})`,
    );
  } catch (e) {
    logError(`broadcastToActors: ${e.message}`);
  }
}

function broadcastUserstyles() {
  if (!actorReady) return;
  let total = 0,
    sent = 0,
    skipped = 0;
  try {
    const windows = Services.wm.getEnumerator("navigator:browser");
    while (windows.hasMoreElements()) {
      const win = windows.getNext();
      if (!win.gBrowser) continue;
      for (const tab of win.gBrowser.tabs) {
        total++;
        try {
          const browser = tab.linkedBrowser;
          if (!browser) {
            skipped++;
            continue;
          }
          const bc = browser.browsingContext;
          if (!bc) {
            skipped++;
            continue;
          }
          const wg = bc.currentWindowGlobal;
          if (!wg) {
            skipped++;
            continue;
          }
          const actor = wg.getActor(ACTOR_NAME);
          if (!actor) {
            skipped++;
            continue;
          }
          let hostname = "";
          try {
            if (browser.currentURI) hostname = browser.currentURI.host || "";
          } catch (e) {}
          const css = getUserstylesForHostname(hostname);
          if (css) {
            actor.sendAsyncMessage("Matugen:ApplyUserstyles", css);
            sent++;
          } else {
            skipped++;
          }
        } catch (e) {
          skipped++;
        }
      }
    }
    logInfo(
      `Broadcast userstyles to ${sent}/${total} tab actors (skipped=${skipped})`,
    );
  } catch (e) {
    logError(`broadcastUserstyles: ${e.message}`);
  }
}

function onPrefChange() {
  const values = collectValues();
  applyChromeVars(values);
  broadcastToActors(values);
}

function observePref(subject, topic, data) {
  if (topic !== "nsPref:changed") return;
  if (!data || !data.startsWith("matugen.theme.")) return;
  if (suppressBroadcast) return;
  onPrefChange();
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
    // Also push the new palette into the active Zen workspace's
    // theme gradient. Zen's boost C++ layer reads
    // workspace.theme.gradientColors[primary].c when
    // boostData.autoTheme is true, so without this push the
    // universal tints won't hot-reload — they keep the gradient
    // color from when the boost was first applied.
    syncWorkspaceTheme(data);
  }
}

// Convert "#fcb974" / "#fff" to [r, g, b] in 0..1 floats.
function hexToRgb01(hex) {
  if (!hex || typeof hex !== "string") return null;
  let s = hex.trim().replace(/^#/, "");
  if (s.length === 3)
    s = s
      .split("")
      .map((c) => c + c)
      .join("");
  if (s.length !== 6) return null;
  const r = parseInt(s.slice(0, 2), 16) / 255;
  const g = parseInt(s.slice(2, 4), 16) / 255;
  const b = parseInt(s.slice(4, 6), 16) / 255;
  if ([r, g, b].some((v) => Number.isNaN(v))) return null;
  return [r, g, b];
}

// Convert [r,g,b] in 0..1 to {h, s, l} in degrees/0..1/0..1.
function rgbToHsl(r, g, b) {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h, s;
  if (max === min) {
    h = s = 0; // achromatic
  } else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r:
        h = (g - b) / d + (g < b ? 6 : 0);
        break;
      case g:
        h = (b - r) / d + 2;
        break;
      case b:
        h = (r - g) / d + 4;
        break;
    }
    h *= 60; // to degrees
  }
  return { h, s, l };
}

function syncWorkspaceTheme(data, force = false) {
  let accentHex = data?.accent;
  if (!accentHex) {
    try {
      accentHex = Services.prefs.getStringPref("matugen.theme.accent", "");
    } catch (e) {}
  }
  if (!accentHex) return;
  if (!force && accentHex === lastSyncedAccent) return;
  logInfo(`syncWorkspaceTheme: called with accent=${accentHex} (force=${force})`);
  try {
    const win = Services.wm.getMostRecentWindow("navigator:browser");
    if (!win) {
      logWarn("syncWorkspaceTheme: no browser window");
      return;
    }
    const accentRgb = hexToRgb01(accentHex);
    if (!accentRgb) {
      logWarn(`syncWorkspaceTheme: bad accent ${accentHex}`);
      return;
    }
    const [r, g, b] = accentRgb;
    const { h, s, l } = rgbToHsl(r, g, b);
    logInfo(
      `syncWorkspaceTheme: accent=${accentHex} → hsl(${h.toFixed(1)}°, ${(s * 100).toFixed(0)}%, ${(l * 100).toFixed(0)}%)`,
    );

    let isLightMode = false;
    try {
      const bgHex = data ? data["bg"] : Services.prefs.getStringPref("matugen.theme.bg", "");
      const bgRgb = hexToRgb01(bgHex);
      if (bgRgb) {
        const { l: bgL } = rgbToHsl(bgRgb[0], bgRgb[1], bgRgb[2]);
        isLightMode = bgL > 0.5;
      }
    } catch (e) {}

    let syncedWorkspace = false;

    // Path 1: try to push into the active Zen workspace gradient
    // (used when the user has Zen Workspaces enabled). The C++ boost
    // layer reads workspace.theme.gradientColors[primary].c when
    // boostData.autoTheme is true, so this drives the C++ tint.
    if (win.gZenWorkspaces) {
      const ws = win.gZenWorkspaces.getActiveWorkspace();
      if (ws && ws.theme) {
        let bgDarkHex = data ? data["bg-dark"] : null;
        let bgLightHex = data ? data["bg-light"] : null;
        if (!data) {
          try {
            bgDarkHex = Services.prefs.getStringPref("matugen.theme.bg-dark", "");
            bgLightHex = Services.prefs.getStringPref("matugen.theme.bg-light", "");
          } catch (e) {}
        }
        const bgDark = hexToRgb01(bgDarkHex);
        const bgLight = hexToRgb01(bgLightHex);
        const gradientColors = [{ c: accentRgb, isPrimary: true }];
        if (bgDark) gradientColors.push({ c: bgDark });
        if (bgLight) gradientColors.push({ c: bgLight });
        ws.theme.gradientColors = gradientColors;
        ws.theme.type = "gradient";
        ws.theme.opacity = ws.theme.opacity ?? 0.5;
        ws.theme.texture = ws.theme.texture ?? 0;
        win.gZenWorkspaces.saveWorkspace(ws);
        // Verify the gradient was persisted
        const wsAfter = win.gZenWorkspaces.getActiveWorkspace();
        const gAfter = wsAfter?.theme?.gradientColors;
        const match = gAfter && gAfter[0] && gAfter[0].c &&
          Math.abs(gAfter[0].c[0] - accentRgb[0]) < 0.01 &&
          Math.abs(gAfter[0].c[1] - accentRgb[1]) < 0.01 &&
          Math.abs(gAfter[0].c[2] - accentRgb[2]) < 0.01;
        logInfo(
          `Synced workspace gradient: ${gradientColors.length} color(s) from accent ${accentHex} (verified=${!!match})`,
        );
        Services.obs.notifyObservers(null, "zen-space-gradient-update");
        syncedWorkspace = true;
      }
    }

    logInfo(
      "syncWorkspaceTheme: finished workspace gradient sync, continuing to direct HSL on boosts",
    );

    // Path 2: directly update the dot-picker knobs on every
    // universal-boosted domain. The C++ tint layer reads
    // dotAngleDeg/saturation/brightness (HSL in disguise) — see
    // ZenBoostsChild.#buildBoostColor. This works for users
    // without Zen Workspaces enabled.
    if (!boostsManager) {
      logWarn("syncWorkspaceTheme: no boostsManager for HSL fallback");
      return;
    }
    let updated = 0;
    let failed = 0;
    for (const domain of universalBoostedDomains) {
      try {
        const boost = boostsManager.loadActiveBoostFromStore(domain);
        if (!boost) {
          failed++;
          logWarn(`HSL fallback: no active boost for ${domain}`);
          continue;
        }
        const { boostData } = boost.boostEntry;
        boostData.autoTheme = false;
        boostData.dotAngleDeg = h;
        boostData.saturation = 1 - s;
        boostData.brightness = Math.max(0, Math.min(1, (l - 0.1) / 0.9));
        boostData.secondaryDotAngleDegDelta = isLightMode ? 0 : 55;
        boostData.enableColorBoost = true;
        boostData.changeWasMade = true;
        boostsManager.updateBoost(boost);
        updated++;
      } catch (e) {
        failed++;
        logError(`update boost[${domain}] HSL: ${e.message}`);
      }
    }
    logInfo(`HSL fallback: updated ${updated} boost(s), failed ${failed}, from accent ${accentHex}`);
    if (updated > 0 || syncedWorkspace) {
      lastSyncedAccent = accentHex;
    }
  } catch (e) {
    logError(`syncWorkspaceTheme: ${e.message}\n${e.stack || ""}`);
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

function poll() {
  try {
    // Check custom web theme state file
    try {
      const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
      const homeDir = Services.dirsvc.get("Home", Ci.nsIFile).path;
      file.initWithPath(homeDir + "/.cache/quickshell/custom_web_theme_state");
      if (file.exists()) {
        const m = file.lastModifiedTime;
        if (m !== lastWebThemeStateMtime) {
          lastWebThemeStateMtime = m;
          const text = readFile(file);
          const nextVal = text.trim() !== "false";
          if (nextVal !== customWebThemeEnabled) {
            customWebThemeEnabled = nextVal;
            logInfo(
              `Custom web theme state changed to: ${customWebThemeEnabled}`,
            );
            broadcastUserstyles();
          }
        }
      } else {
        if (lastWebThemeStateMtime !== 0) {
          lastWebThemeStateMtime = 0;
          if (!customWebThemeEnabled) {
            customWebThemeEnabled = true;
            logInfo(`Custom web theme state file deleted, default to enabled`);
            broadcastUserstyles();
          }
        }
      }
    } catch (e) {
      logError(`poll web theme state: ${e.message}`);
    }

    if (jsonFile && jsonFile.exists()) {
      const mtime = jsonFile.lastModifiedTime;
      if (mtime !== lastMtime) {
        lastMtime = mtime;
        logInfo(`matugen-vars.json mtime changed: ${mtime}`);
        const data = readJson();
        if (data) applyJson(data);
      }
    }
    if (userstylesDir && userstylesDir.exists()) {
      let changed = false;
      // global
      const globalFile = userstylesDir.clone();
      globalFile.append(USERSTYLES_GLOBAL);
      if (globalFile.exists()) {
        const m = globalFile.lastModifiedTime;
        const cur = userstyles.global;
        if (!cur || cur.mtime !== m) {
          loadUserstylesFor("global", globalFile);
          changed = true;
        }
      }
      // per-host files
      try {
        const entries = userstylesDir.directoryEntries;
        while (entries.hasMoreElements()) {
          const raw = entries.getNext();
          try {
            const f = raw.QueryInterface(Ci.nsIFile);
            const fname = f.leafName;
            if (!fname || !fname.startsWith(USERSTYLES_PREFIX)) continue;
            if (fname === USERSTYLES_GLOBAL) continue;
            if (!f.isFile()) continue;
            const suffix = fname.slice(USERSTYLES_PREFIX.length, -4);
            // Skip disabled files (e.g. foo.css.disabled) — they're
            // not active userstyles.
            if (fname.endsWith(".disabled")) continue;
            const m = f.lastModifiedTime;
            const cur = userstyles[suffix];
            if (!cur || cur.mtime !== m) {
              loadUserstylesFor(suffix, f);
              changed = true;
            }
          } catch (e) {}
        }
      } catch (e) {}
      // If a previously-known suffix is no longer in the dir (file
      // renamed to .disabled, or deleted), clear the boost's
      // customCSS so the page reverts to Zen's defaults.
      const currentSuffixes = new Set();
      try {
        const entries = userstylesDir.directoryEntries;
        while (entries.hasMoreElements()) {
          const raw = entries.getNext();
          try {
            const f = raw.QueryInterface(Ci.nsIFile);
            const fname = f.leafName;
            if (!fname || !fname.startsWith(USERSTYLES_PREFIX)) continue;
            if (fname === USERSTYLES_GLOBAL) continue;
            if (!f.isFile()) continue;
            if (fname.endsWith(".disabled")) continue;
            const suffix = fname.slice(USERSTYLES_PREFIX.length, -4);
            currentSuffixes.add(suffix);
          } catch (e) {}
        }
      } catch (e) {}
      for (const [domain, config] of Object.entries(BOOST_SITES)) {
        const fileSuffix = config.cssFile.slice(USERSTYLES_PREFIX.length, -4);
        if (!currentSuffixes.has(fileSuffix) && userstyles[fileSuffix]) {
          logInfo(
            `Userstyles[${fileSuffix}] removed, clearing boost[${domain}].customCSS`,
          );
          userstyles[fileSuffix] = { css: "", mtime: 0, path: null };
          if (boostsManager) {
            try {
              const boost = getOrCreateActiveBoost(domain);
              if (boost) {
                boost.boostEntry.boostData.customCSS = "";
                boost.boostEntry.boostData.changeWasMade = false;
                boostsManager.updateBoost(boost);
              }
            } catch (e) {
              logError(`clear boost[${domain}]: ${e.message}`);
            }
          }
          changed = true;
        }
      }
      if (changed) {
        logInfo(`Userstyles changed, broadcasting`);
        broadcastUserstyles();
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

  // Universal boost sync runs less frequently — it walks all open
  // tabs and creates a Zen Boost for any unhosted domain. We don't
  // need to do this every second; a few seconds is fine because the
  // user only notices after they navigate to a new site anyway.
  if (universalPollTimer) return;
  universalPollTimer = setInterval(() => {
    try {
      syncUniversalBoosts();
    } catch (e) {
      logError(`Universal poll: ${e.message}`);
    }
  }, 3000);
  logInfo(`Universal boost sync every 3000ms`);
}

function resolveChromeDir() {
  try {
    return Services.dirsvc.get("UChrm", Ci.nsIFile);
  } catch (e) {
    logError(`resolveChromeDir: ${e.message}`);
    return null;
  }
}

function registerActor() {
  try {
    ChromeUtils.registerWindowActor(ACTOR_NAME, {
      parent: { esModuleURI: ACTOR_PARENT_URI },
      child: {
        esModuleURI: ACTOR_CHILD_URI,
        events: { DOMContentLoaded: {} },
      },
      matches: ["<all_urls>"],
      remoteTypes: ["web", "privilegedabout", "moz-extension", null],
      allFrames: false,
      includeChrome: true,
    });
    actorReady = true;
    logInfo(`Registered Matugen JSWindowActor (chrome:// URIs)`);
  } catch (e) {
    actorReady = false;
    logError(`Actor registration error: ${e.message}`);
  }
}

async function init() {
  try {
    chromeDir = resolveChromeDir();
    if (!chromeDir) {
      logError("Could not resolve chrome dir");
      return;
    }
    logInfo(`chrome dir: ${chromeDir.path}`);

    // openLog is no longer needed — _appendLog opens the file per-write

    jsonFile = chromeDir.clone();
    jsonFile.append("matugen-vars.json");
    logInfo(`Watching: ${jsonFile.path}`);

    userstylesDir = chromeDir.clone();
    logInfo(`Watching: ${userstylesDir.path} for matugen-userstyles*.css`);

    const state = readWebThemeState();
    customWebThemeEnabled = state.enabled;
    lastWebThemeStateMtime = state.mtime;
    logInfo(`Initial custom web theme enabled state: ${customWebThemeEnabled}`);

    // Load Zen's boost manager — used to push per-site userstyles into
    // Zen Boosts (customCSS) so Zen's built-in actor injects them as
    // AGENT_SHEETs. Failure is non-fatal: we just skip boost sync.
    boostsManager = await loadBoostsManager();
    if (boostsManager) {
      logInfo("Loaded Zen Boosts Manager");
    } else {
      logWarn(
        "Zen Boosts Manager not available — per-site CSS will only be injected via the actor fallback",
      );
    }

    registerActor();
    registerPrefObservers();

    if (jsonFile.exists()) {
      const data = readJson();
      if (data) {
        lastMtime = jsonFile.lastModifiedTime;
        applyJson(data);
        logInfo("Initial apply on startup");
      }
    } else {
      logInfo("matugen-vars.json not present yet, will wait for first write");
    }

    loadAllUserstyles();

    startPolling();

    // Initial pass: tint any open tabs that don't yet have a boost.
    if (boostsManager) {
      try {
        const created = syncUniversalBoosts();
        if (created > 0) {
          logInfo(`Initial universal boost sync: ${created} new boost(s)`);
        }
      } catch (e) {
        logError(`Initial universal sync: ${e.message}`);
      }
    }
  } catch (e) {
    logError(`Init: ${e.message}\n${e.stack || ""}`);
  }
}

// Expose state for the parent actor module which is loaded
// in a different scope. The parent uses globalThis.__matugenBridge
// set by fx-autoconfig's actor wrapper. We expose the userstyles
// cache and a getter (by hostname) that the parent's
// receiveMessage can call. Also a log() helper so the parent
// can forward child-actor log messages to our log file.
globalThis.__matugenBridge = {
  getUserstyles: (hostname) => {
    const result = getUserstylesForHostname(hostname);
    try {
      const parts = (hostname || "").split(".");
      let suffix = null;
      for (let i = 0; i < parts.length; i++) {
        const candidate = parts.slice(i).join(".");
        if (HOST_TO_FILE[candidate]) {
          suffix = HOST_TO_FILE[candidate];
          break;
        }
      }
      logInfo(
        `[bridge.getUserstyles] host="${hostname}" suffix="${suffix}" userstyles.global=${userstyles.global ? userstyles.global.css.length : "null"} userstyles.${suffix}=${userstyles[suffix] ? userstyles[suffix].css.length : "null"} -> ${result.length}B`,
      );
    } catch (e) {}
    return result;
  },
  log: (level, msg) => {
    if (level === "CHILD") {
      logInfo(`[child] ${msg}`);
    } else if (level === "ERROR") {
      logError(msg);
    } else {
      logInfo(msg);
    }
  },
};

init().catch((e) => logError(`init() failed: ${e.message}\n${e.stack || ""}`));
