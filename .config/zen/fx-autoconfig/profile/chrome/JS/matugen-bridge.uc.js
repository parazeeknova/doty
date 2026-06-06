// ==UserScript==
// @name matugen-bridge
// @description Bridges matugen color JSON to Firefox CSS variables (chrome + content via JSWindowActor), and injects per-site userstyles CSS into content documents.
// @author doty
// @version 1.4
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
  try { console.log(line); } catch (e) {}
  try {
    const p = _logFile();
    if (p) {
      const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
      file.initWithPath(p);
      const foStream = Cc["@mozilla.org/network/file-output-stream;1"]
        .createInstance(Ci.nsIFileOutputStream);
      // PR_WRITE_ONLY | PR_CREATE_FILE | PR_APPEND
      foStream.init(file, 0x02 | 0x08 | 0x10, 0o644, 0);
      foStream.write(line, line.length);
      foStream.flush();
      foStream.close();
    }
  } catch (e) {
    try { console.log("[matugen-bridge] log write failed: " + e); } catch (e2) {}
  }
}
function logInfo(msg) { _appendLog("INFO", msg); }
function logWarn(msg) { _appendLog("WARN", msg); }
function logError(msg) { _appendLog("ERROR", msg); }

logInfo("SCRIPT TOP — version 1.4");

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

const ACTOR_NAME = "Matugen";
const ACTOR_PARENT_URI = "chrome://userscripts/content/Matugen/MatugenParent.sys.mjs";
const ACTOR_CHILD_URI = "chrome://userscripts/content/Matugen/MatugenChild.sys.mjs";
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

let chromeDir = null;
let jsonFile = null;
let userstylesDir = null;
let userstyles = {
  // global: { css, mtime, path }
  // github: { css, mtime, path }
};
let lastMtime = 0;
let pollTimer = null;
let actorReady = false;
let suppressBroadcast = false;

function readFile(file) {
  try {
    const fstream = Cc["@mozilla.org/network/file-input-stream;1"]
      .createInstance(Ci.nsIFileInputStream);
    fstream.init(file, -1, 0, 0);
    const converter = Cc["@mozilla.org/intl/converter-input-stream;1"]
      .createInstance(Ci.nsIConverterInputStream);
    converter.init(fstream, "utf-8", 4096,
      Ci.nsIConverterInputStream.DEFAULT_REPLACEMENT_CHARACTER);
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
    logInfo(`Loaded userstyles[${name}]: ${css.length} bytes from ${file.path}`);
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
        if (!f.isFile()) continue;
        const suffix = fname.slice(USERSTYLES_PREFIX.length, -4); // strip prefix and .css
        loadUserstylesFor(suffix, f);
        found++;
      } catch (e) {
        logError(`scan entry error: ${e.message}`);
      }
    }
    if (found > 0) logInfo(`Scanned userstyles dir: ${found} per-site file(s) (${Object.keys(userstyles).filter(k => k !== "global").join(", ")})`);
  } catch (e) {
    logError(`scan userstyles dir: ${e.message}`);
  }
}

function getUserstylesForHostname(hostname) {
  const parts = (hostname || "").split(".");
  let suffix = null;
  for (let i = 0; i < parts.length; i++) {
    const candidate = parts.slice(i).join(".");
    if (HOST_TO_FILE[candidate]) {
      suffix = HOST_TO_FILE[candidate];
      break;
    }
  }
  const out = [];
  if (userstyles.global && userstyles.global.css) {
    out.push(userstyles.global.css);
  }
  if (suffix && userstyles[suffix] && userstyles[suffix].css) {
    out.push(userstyles[suffix].css);
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
  let total = 0, sent = 0, skipped = 0;
  try {
    const windows = Services.wm.getEnumerator("navigator:browser");
    while (windows.hasMoreElements()) {
      const win = windows.getNext();
      if (!win.gBrowser) continue;
      for (const tab of win.gBrowser.tabs) {
        total++;
        try {
          const browser = tab.linkedBrowser;
          if (!browser) { skipped++; continue; }
          const bc = browser.browsingContext;
          if (!bc) { skipped++; continue; }
          const wg = bc.currentWindowGlobal;
          if (!wg) { skipped++; continue; }
          const actor = wg.getActor(ACTOR_NAME);
          if (!actor) { skipped++; continue; }
          actor.sendAsyncMessage("Matugen:ApplyVars", values);
          sent++;
        } catch (e) {
          skipped++;
        }
      }
    }
    logInfo(`Broadcast vars to ${sent}/${total} tab actors (skipped=${skipped})`);
  } catch (e) {
    logError(`broadcastToActors: ${e.message}`);
  }
}

function broadcastUserstyles() {
  if (!actorReady) return;
  let total = 0, sent = 0, skipped = 0;
  try {
    const windows = Services.wm.getEnumerator("navigator:browser");
    while (windows.hasMoreElements()) {
      const win = windows.getNext();
      if (!win.gBrowser) continue;
      for (const tab of win.gBrowser.tabs) {
        total++;
        try {
          const browser = tab.linkedBrowser;
          if (!browser) { skipped++; continue; }
          const bc = browser.browsingContext;
          if (!bc) { skipped++; continue; }
          const wg = bc.currentWindowGlobal;
          if (!wg) { skipped++; continue; }
          const actor = wg.getActor(ACTOR_NAME);
          if (!actor) { skipped++; continue; }
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
    logInfo(`Broadcast userstyles to ${sent}/${total} tab actors (skipped=${skipped})`);
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
    onPrefChange();
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
            const m = f.lastModifiedTime;
            const cur = userstyles[suffix];
            if (!cur || cur.mtime !== m) {
              loadUserstylesFor(suffix, f);
              changed = true;
            }
          } catch (e) {}
        }
      } catch (e) {}
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

function init() {
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
      logInfo(`[bridge.getUserstyles] host="${hostname}" suffix="${suffix}" userstyles.global=${userstyles.global ? userstyles.global.css.length : "null"} userstyles.${suffix}=${userstyles[suffix] ? userstyles[suffix].css.length : "null"} -> ${result.length}B`);
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

init();
