// MatugenChild - child side of the Matugen JSWindowActor.
// Runs in each content process. On DOMContentLoaded and on every
// "Matugen:ApplyVars" message, sets --matugen-* CSS custom
// properties on the content document's <html> element so the
// content CSS (userContent.css) can use var(--matugen-accent) etc.

"use strict";

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

function readPrefs() {
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

function applyVars(values) {
  if (!values) return;
  const doc = this.document;
  if (!doc) return;
  const root = doc.documentElement;
  if (!root) return;
  for (const [varName, val] of Object.entries(values)) {
    if (!val) continue;
    try {
      root.style.setProperty(varName, val);
    } catch (e) {}
  }
}

export class MatugenChild extends JSWindowActorChild {
  handleEvent(event) {
    if (event.type === "DOMContentLoaded") {
      try {
        applyVars.call(this, readPrefs());
      } catch (e) {}
    }
  }

  receiveMessage(message) {
    if (!message) return null;
    if (message.name === "Matugen:ApplyVars") {
      try {
        applyVars.call(this, message.data);
      } catch (e) {}
    }
    return null;
  }
}
