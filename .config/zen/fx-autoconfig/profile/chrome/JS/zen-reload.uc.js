// Zen Browser userChrome.css live-reload watcher
// Loaded by fx-autoconfig (MrOtherGuy/fx-autoconfig) at startup.
// Reloads chrome/userChrome.css when the file changes on disk.

"use strict";

const POLL_MS = 1500;
const STYLE_KEY = "zen-watcher-marker";

let cssFile = null;
let cssURI = null;
let sss = null;
let lastMtime = 0;

function init() {
  try {
    cssFile = Services.dirsvc.get("UChrm", Ci.nsIFile);
    cssFile.append("userChrome.css");

    if (!cssFile.exists()) {
      console.warn("[zen-reload] userChrome.css not found at:", cssFile.path);
      return;
    }

    cssURI = Services.io.newFileURI(cssFile);
    sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(
      Ci.nsIStyleSheetService
    );

    lastMtime = cssFile.lastModifiedTime;
    console.log("[zen-reload] Watching:", cssFile.path);
    startPolling();
  } catch (e) {
    console.error("[zen-reload] Init error:", e);
  }
}

function startPolling() {
  setInterval(() => {
    try {
      if (!cssFile || !cssFile.exists()) return;
      const mtime = cssFile.lastModifiedTime;
      if (mtime === lastMtime) return;
      lastMtime = mtime;
      console.log("[zen-reload] userChrome.css changed, reloading");
      reload();
    } catch (e) {
      console.error("[zen-reload] Poll error:", e);
    }
  }, POLL_MS);
}

function reload() {
  try {
    if (!sss || !cssURI) return;
    for (const type of [sss.USER_SHEET, sss.AGENT_SHEET]) {
      if (sss.sheetRegistered(cssURI, type)) {
        sss.unregisterSheet(cssURI, type);
      }
      sss.loadAndRegisterSheet(cssURI, type);
    }
    Services.obs.notifyObservers(null, "chrome-flush-caches", null);
    console.log("[zen-reload] Reloaded userChrome.css");
  } catch (e) {
    console.error("[zen-reload] Reload error:", e);
  }
}

setTimeout(init, 1000);
