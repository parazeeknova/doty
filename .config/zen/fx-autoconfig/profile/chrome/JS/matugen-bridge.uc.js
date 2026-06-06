// ==UserScript==
// @name matugen-bridge
// @description Bridges matugen color JSON to Firefox CSS variables (chrome + content via JSWindowActor)
// @author doty
// @version 1.1
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

const ACTOR_NAME = "Matugen";
const ACTOR_PARENT_URI = "chrome://userscripts/content/Matugen/MatugenParent.sys.mjs";
const ACTOR_CHILD_URI = "chrome://userscripts/content/Matugen/MatugenChild.sys.mjs";

let chromeDir = null;
let jsonFile = null;
let lastMtime = 0;
let pollTimer = null;
let logStream = null;
let logFilePath = null;
let actorReady = false;
let suppressBroadcast = false;

function logInfo(msg) { logLine("INFO", msg); }
function logWarn(msg) { logLine("WARN", msg); }
function logError(msg) { logLine("ERROR", msg); }

function logLine(level, msg) {
  const line = `[matugen-bridge] [${level}] ${msg}`;
  try { console.log(line); } catch (e) {}
  if (logStream) {
    try {
      logStream.write(line + "\n");
      logStream.flush();
    } catch (e) {
      try { logStream.close(); } catch (e2) {}
      logStream = null;
    }
  }
}

function openLog(chromeDirPath) {
  try {
    const logFile = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
    logFile.initWithPath(chromeDirPath);
    logFile.append("matugen-bridge.log");
    logFilePath = logFile.path;
    logStream = Cc["@mozilla.org/network/file-output-stream;1"]
      .createInstance(Ci.nsIFileOutputStream);
    logStream.init(logFile, 0x02 | 0x08 | 0x10, 0o644, 0);
  } catch (e) {
    logStream = null;
  }
}

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
  if (!actorReady) {
    logInfo(`Broadcast skipped: actor not registered`);
    return;
  }
  const data = { name: "Matugen:ApplyVars", values };
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
          actor.sendAsyncMessage(data.name, data.values);
          sent++;
        } catch (e) {
          skipped++;
        }
      }
    }
    logInfo(`Broadcast to ${sent}/${total} tab actors (skipped=${skipped})`);
  } catch (e) {
    logError(`broadcastToActors: ${e.message}`);
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
    if (!jsonFile || !jsonFile.exists()) return;
    const mtime = jsonFile.lastModifiedTime;
    if (mtime === lastMtime) return;
    lastMtime = mtime;
    logInfo(`matugen-vars.json mtime changed: ${mtime}`);
    const data = readJson();
    if (data) applyJson(data);
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

    openLog(chromeDir.path);

    jsonFile = chromeDir.clone();
    jsonFile.append("matugen-vars.json");
    logInfo(`Watching: ${jsonFile.path}`);

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

    startPolling();
  } catch (e) {
    logError(`Init: ${e.message}\n${e.stack || ""}`);
  }
}

init();
