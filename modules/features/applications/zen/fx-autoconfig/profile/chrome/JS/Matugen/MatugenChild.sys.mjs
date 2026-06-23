// MatugenChild - child side of the Matugen JSWindowActor.
// Runs in each content process. On DOMContentLoaded and on every
// "Matugen:ApplyVars" message, sets --matugen-* CSS custom
// properties on the content document's <html> element so the
// content CSS can use var(--matugen-accent) etc.
//
// Also injects the matugen userstyles CSS as a <style> element.
// The bridge reads the CSS file from disk and ships it as a
// message. We inject it once on DOMContentLoaded (after asking
// the parent for the current CSS via sendQuery) and replace it
// whenever the parent broadcasts a new "Matugen:ApplyUserstyles".
//
// Many sites (GitHub, etc.) lazy-load critical content after
// DCL. The userstyles <style> element persists in the head, but
// the new elements it needs to style aren't there yet. We use
// a MutationObserver on the body to re-inject userstyles when
// significant DOM changes happen (debounced to avoid spam).

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

const STYLE_ID = "matugen-userstyles";

let _lastInjectedCss = "";
let _observer = null;
let _observerTimer = null;

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
  const doc = this.document || (this.contentWindow && this.contentWindow.document);
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

function injectUserstyles(css) {
  if (!css) return;
  _lastInjectedCss = css;
  const doc = this.document || (this.contentWindow && this.contentWindow.document);
  if (!doc) return;
  const head = doc.head || doc.documentElement;
  if (!head) return;

  let style = doc.getElementById(STYLE_ID);
  if (!style) {
    style = doc.createElementNS("http://www.w3.org/1999/xhtml", "style");
    style.id = STYLE_ID;
    style.setAttribute("type", "text/css");
    head.appendChild(style);
  }
  style.textContent = css;
}

function setupMutationObserver(doc) {
  if (_observer) {
    try { _observer.disconnect(); } catch (e) {}
    _observer = null;
  }
  if (!doc || !doc.body) return;
  try {
    _observer = new MutationObserver(() => {
      if (_observerTimer) clearTimeout(_observerTimer);
      _observerTimer = setTimeout(() => {
        if (_lastInjectedCss && doc.getElementById(STYLE_ID)) {
          const style = doc.getElementById(STYLE_ID);
          if (style.textContent !== _lastInjectedCss) {
            style.textContent = _lastInjectedCss;
          }
        }
      }, 200);
    });
    _observer.observe(doc.body, { childList: true, subtree: true });
  } catch (e) {}
}

export class MatugenChild extends JSWindowActorChild {
  async handleEvent(event) {
    if (event.type === "DOMContentLoaded") {
      try {
        applyVars.call(this, readPrefs());
      } catch (e) {
        this.sendAsyncMessage("Matugen:ChildLog", `applyVars error: ${e}`);
      }
      try {
        const hostname = (this.document && this.document.location)
          ? this.document.location.hostname
          : "";
        const css = await this.sendQuery("Matugen:GetUserstyles", { hostname });
        this.sendAsyncMessage("Matugen:ChildLog", `DCL ${hostname} got ${css ? css.length : 0}B`);
        if (css) {
          injectUserstyles.call(this, css);
          const doc = this.document || (this.contentWindow && this.contentWindow.document);
          setupMutationObserver(doc);
        }
      } catch (e) {
        this.sendAsyncMessage("Matugen:ChildLog", `DCL error: ${e}`);
      }
    }
  }

  receiveMessage(message) {
    if (!message) return null;
    if (message.name === "Matugen:ApplyVars") {
      try {
        applyVars.call(this, message.data);
      } catch (e) {}
    } else if (message.name === "Matugen:ApplyUserstyles") {
      try {
        const css = message.data;
        const h = (this.document && this.document.location) ? this.document.location.hostname : "?";
        this.sendAsyncMessage("Matugen:ChildLog", `ApplyUserstyles msg ${css ? css.length : 0}B -> ${h}`);
        injectUserstyles.call(this, css);
      } catch (e) {
        this.sendAsyncMessage("Matugen:ChildLog", `ApplyUserstyles err: ${e}`);
      }
    }
    return null;
  }
}
