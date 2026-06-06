// MatugenParent - parent side of the Matugen JSWindowActor.
// Runs in the chrome (browser) process. Handles the
// "Matugen:GetUserstyles" query from the child by reading the
// CSS file(s) directly from the profile chrome dir. The bridge
// (matugen-bridge.uc.js) writes these files on every theme
// switch and we read them on demand so newly-loaded tabs get
// the latest CSS without waiting for a theme switch.
//
// We read files directly (rather than calling into the bridge
// via globalThis) because the parent actor's module scope has
// a different globalThis from the chrome window where the
// bridge script runs, so closures set up by the bridge aren't
// visible here. File I/O is cheap and avoids the cross-scope
// state issue entirely.
//
// Per-site files: matugen-userstyles-<host>.css (e.g.
// matugen-userstyles-github.css). Global: matugen-userstyles.css.
// The parent combines global + matching per-site file.

"use strict";

const HOST_TO_FILE = {
  "github.com": "github",
  "gist.github.com": "github",
  "docs.github.com": "github",
  "raw.githubusercontent.com": "github",
};

const USERSTYLES_PREFIX = "matugen-userstyles-";
const USERSTYLES_GLOBAL = "matugen-userstyles.css";

function _parentLog(level, msg) {
  try {
    const bridge = globalThis.__matugenBridge;
    if (bridge && typeof bridge.log === "function") {
      bridge.log(level, msg);
    } else {
      console.log(`[MatugenParent] [${level}] ${msg}`);
    }
  } catch (e) {
    try { console.log(`[MatugenParent] [${level}] ${msg}`); } catch (e2) {}
  }
}

function _chromeDir() {
  try {
    return Services.dirsvc.get("UChrm", Ci.nsIFile);
  } catch (e) {
    return null;
  }
}

function _readFile(file) {
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

function _getUserstylesForHostname(hostname) {
  const dir = _chromeDir();
  if (!dir) return "";
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
  const globalFile = dir.clone();
  globalFile.append(USERSTYLES_GLOBAL);
  if (globalFile.exists()) {
    const css = _readFile(globalFile);
    if (css) out.push(css);
  }
  if (suffix) {
    const f = dir.clone();
    f.append(USERSTYLES_PREFIX + suffix + ".css");
    if (f.exists()) {
      const css = _readFile(f);
      if (css) out.push(css);
    }
  }
  return out.join("\n/* ---- per-site overlay ---- */\n");
}

export class MatugenParent extends JSWindowActorParent {
  receiveMessage(message) {
    if (!message) return null;
    if (message.name === "Matugen:GetUserstyles") {
      const hostname = (message.data && message.data.hostname) || "";
      const css = _getUserstylesForHostname(hostname);
      _parentLog("CHILD", `GetUserstyles "${hostname}" -> ${css.length}B`);
      return css;
    }
    if (message.name === "Matugen:ChildLog") {
      _parentLog("CHILD", String(message.data || ""));
      return null;
    }
    return null;
  }
}
