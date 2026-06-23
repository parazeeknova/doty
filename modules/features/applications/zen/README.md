# Zen Browser + matugen dynamic theming

A write-up of how I (finally) got my matugen palette to drive my Zen Browser
theme live, in both chrome (sidebar, tabs, popups) **and** web content
(`::selection`, etc.). Includes the dead-ends, the stupid bugs, and the
architecture that actually stuck.

If you're reading this, you're either me in three months, or someone with
the same problem. Either way: sorry, this took a while.

---

## The goal

I have a Hyprland setup driven by [wabi](https://github.com/), a Rust
theme switcher. It already produces a matugen palette and a colors.json
under `~/.cache/quickshell/`. I wanted that same palette to drive Zen:

- Sidebar text/icons in the accent color.
- Selected tab uses a subtle `bg-light`, not bright accent.
- Sharp corners, no panel shadows, subtle accent border on popups.
- `::selection` on **websites** uses accent (not just chrome).
- All of it updates **live** when I switch wallpaper — no Zen restart.

Last bullet is the one that killed the obvious approach.

---

## What I have to work with

- Zen Browser installed at `/opt/zen-browser-bin/` (root-owned package build).
- Two profiles: `v1oocp83.Default (release)` and `oxw0c1nv.Default Profile`.
- [fx-autoconfig](https://github.com/MrOtherGuy/fx-autoconfig) for arbitrary
  userChrome.js / userChrome.css / userContent.css injection.
- A Quickshell bar that runs my Rust `theme_switcher` on wallpaper change
  (`Quickshell.execDetached([homeDir + "/doty/scripts/theme_switcher", "wallpaper", path])`).
- wabi builds me a matugen palette already — I just need to get it into
  Firefox.

---

## The journey (the long part)

### Phase 1: the "obvious" approach — just template-substitute the CSS

My first move was the boring one. Make `userChrome.css.template` with
`{{accent}}`, `{{bg}}`, etc. placeholders, have the switcher fill them in
and write the file to the profile. Done. Restart Zen, get colored sidebar.

This worked. It was also completely useless to me, because the whole point
was *not restarting Zen* on every wallpaper change.

So I needed live updates. I knew I could do that with the CSSOM:

```js
document.documentElement.style.setProperty('--matugen-accent', '#a9b665');
```

The trick is getting the JS to run with the right values. Where does the JS
live, and where does it learn the colors?

### Phase 2: poll from a userChrome.js script

`fx-autoconfig` lets you drop a `*.uc.js` in `chrome/JS/` and it auto-loads
it. I figured: poll a file, set inline CSS vars on `:root`, done.

I did that. The chrome side updated live. Beautiful. I was patting myself
on the back.

Then I switched a tab. The new website didn't have my colors. Of course it
didn't — `:root` lives in the chrome document, web content has its own
`:root`. CSS custom properties don't cross document boundaries. I knew
this. I did it anyway.

To push vars into content documents, I need code running *in* the content
process. In modern Firefox/Zen with **Fission on** (and it is on by
default), that's a JSWindowActor. No more `loadFrameScript`. No more
content scripts the easy way.

### Phase 3: the JSWindowActor crash era

OK, JSWindowActor. The actor has a `parent` (chrome process) and `child`
(content process). When the parent sends a message, the child handles it.

The actor's `esModuleURI` is supposed to be a real `chrome://` URI. But I
didn't have a chrome package set up; my files were just sitting in
`JS/`. So I thought: data: URI. Encode the module as base64, set
`esModuleURI` to `data:application/javascript;base64,...`. Same trick for
the stylesheet — `data:text/css;base64,...` and feed it to
`Services.scriptStyleSheetLoader.loadAndRegisterSheet`.

This compiled. The bridge logged that it registered. Then I switched
themes and Zen hard-crashed. Not "stopped responding" — *crashed*. The
whole browser window vanished.

I tried several permutations:
- Inline the child as a string and use a `data:` URI for the actor.
- Skip the actor entirely and use a polling content script via
  `loadFrameScript` (rejected — Fission).
- Set `Services.scriptStyleSheetLoader` sheets via data: URIs from a
  per-frame message.

Every time, switching themes under load killed the browser. The data: URI
trick was clearly upsetting something low-level in Firefox. Maybe CSP, maybe
the sheet loader's caching, maybe something in the actor's module loader.

I threw all of that code out. Time for a different architecture.

### Phase 4: Path B — the right one

The key insight: **Firefox already has a way to ship strings from the
chrome process to the content process: prefs.** `Services.prefs` is
visible everywhere, pref changes fire observers in every process, and
content processes can read pref values directly.

So the new architecture:

1. Switcher (Rust) writes a small JSON file:
   `matugen-vars.json` with the 8 matugen colors.
2. A `matugen-bridge.uc.js` in `chrome/JS/` polls the JSON's mtime.
3. When it changes, the bridge writes 8 `matugen.theme.*` string prefs.
4. Pref observers in the bridge fire → it sets inline CSS vars on
   `document.documentElement` (chrome `:root`).
5. A JSWindowActor's child side listens for either pref changes or a
   `Matugen:ApplyVars` message, and sets the same vars on each content
   document's `:root`.

No custom sheet loading. No data: URIs. No `loadAndRegisterSheet`. The
content process just gets the values and sets CSS variables — exactly
what the chrome process does. The CSS in `userChrome.css` and
`userContent.css` uses `var(--matugen-accent)`, etc., so changing the
inline style on `:root` instantly updates everything.

I liked this. It uses platform mechanisms instead of fighting them.

### Phase 5: the chrome://userscripts discovery

fx-autoconfig's `chrome.manifest` has this line:

```
content userscripts ../JS/
```

That means `chrome://userscripts/content/foo` resolves to `JS/foo` in
the profile. So I can drop a file at `JS/Matugen/MatugenChild.sys.mjs`
and reference it from anywhere as
`chrome://userscripts/content/Matugen/MatugenChild.sys.mjs`. That's a
real `chrome://` URI, the kind `ChromeUtils.registerWindowActor` is
happy with.

No more data: URIs. No more crashes from that vector.

### Phase 6: the @WindowActor directive (and the JSON.parse gotcha)

fx-autoconfig has experimental support for JSWindowActors. You add a
header to a `.uc.js` file:

```js
// ==UserScript==
// @name matugen-bridge
// @WindowActor Matugen
// @WindowActorMatches ["<all>"]
// ==/UserScript==
```

fx-autoconfig parses these on load and registers the actor via
`ActorManagerParent.addJSWindowActors`.

I tried that. The bridge loaded. Then I switched themes. The broadcast
went to `0/25` tab actors.

Worse: when I had `@WindowActorMatches '["<all>"]'` (with single quotes
around the array — a habit from Python), fx-autoconfig barfed with
`SyntaxError: JSON.parse`. The directive value is parsed as JSON.
`"[\"<all>\"]"` works; `'["<all>"]'` does not. Easy fix, easy to miss.

Removing the quotes gave me a clean log. But the actor was still
`0/25`. Why?

### Phase 7: why 0/25?

I read `fx-autoconfig`'s `boot.sys.mjs` (specifically the
`buildScriptActorDefinition` function). The actor definition is
hardcoded with:

```js
remoteTypes: ["privilegedabout", null],
```

`null` is the default for `about:blank`. `"privilegedabout"` is for
privileged about: pages. But regular web content (http/https) has
`remoteType: "web"`. So the actor was registered, but never *created*
for any of my 25 web tabs.

The fix: don't use fx-autoconfig's `@WindowActor` directive. Register
the actor manually from inside the bridge, with the right `remoteTypes`:

```js
ChromeUtils.registerWindowActor("Matugen", {
  parent: { esModuleURI: "chrome://userscripts/content/Matugen/MatugenParent.sys.mjs" },
  child:  { esModuleURI: "chrome://userscripts/content/Matugen/MatugenChild.sys.mjs",
            events: { DOMContentLoaded: {} } },
  matches: ["<all_urls>"],
  remoteTypes: ["web", "privilegedabout", "moz-extension", null],
  allFrames: false,
  includeChrome: true,
});
```

Removed the `@WindowActor` / `@WindowActorMatches` headers from the
bridge. Deployed. Restarted Zen.

`Broadcast to 1/25 tab actors (skipped=24)`.

The 24 skipped aren't broken — they're background/unloaded tabs that
don't have a `currentWindowGlobal` yet. When you actually switch to
them, they load, the actor's `handleEvent("DOMContentLoaded")` fires,
reads the current prefs, and applies the theme. So they pick up the
current theme lazily. I tested this and it works.

### Phase 8: the stale binary

About 2 hours into Phase 7, I was convinced the actor registration was
silently failing. I started wondering if my Rust binary at
`~/doty/scripts/theme_switcher` was even the new one. It was not. It was
from June 5. The new one (June 6, with the JSON-writing code) had never
made it into the deployed location.

The Makefile's `sync` target was failing because some other process
(`wallpaper_thumb_watcher`) was holding the file busy. So `make sync`
silently skipped the copy. The source `target/release/theme_switcher`
was correct, the deployed binary was old.

`cp` manually. Checked the size jumped from 1.16 MB to 1.19 MB. Log
started showing `Wrote 8 prefs from matugen-vars.json`. So the chain
was working end-to-end, I just couldn't see the new writes because
the deployed binary wasn't writing them.

Lesson: when nothing changes despite everything looking right, check
*which* binary is running, not just *that* one is.

### Phase 9: small cleanups

After confirming the live switch works, the log was noisy: 8 broadcasts
per mtime change. Why? Each `setStringPref` call fires the pref
observer synchronously, which calls `onPrefChange`, which broadcasts.
With 8 prefs, that's 8 broadcasts per switch.

Fix: in `applyJson`, suppress the observer while setting the 8 prefs,
then call `onPrefChange()` once at the end. One broadcast per switch.
Logs are readable now.

---

## What worked

- **fx-autoconfig** for injecting `userChrome.css`, `userContent.css`,
  and `*.uc.js` into Zen.
- **`chrome://userscripts/content/...` URIs** — fx-autoconfig's
  `content userscripts ../JS/` mapping. Lets you use real chrome://
  URIs from anything in `JS/` without packaging.
- **JSWindowActor with `ChromeUtils.registerWindowActor` called from
  the bridge** — bypasses fx-autoconfig's hardcoded `remoteTypes` so
  the actor is created for `web` content, not just `privilegedabout`.
- **Pref-driven theming** — Firefox's own IPC for shipping values
  chrome→content. No custom protocols, no data: URIs, no sheet
  loaders.
- **Polling JSON mtime** as the switcher→bridge transport. The
  switcher is a Rust binary, can't call into Firefox; the bridge
  runs in Firefox, can't reach the switcher. A tiny JSON file at
  `chrome/matugen-vars.json` is the cleanest contract between them.
- **Inline `style.setProperty` on `documentElement`** — wins over
  CSS rules, so the bridge overrides the `:root` defaults in the
  template at runtime.
- **Lazy apply via `DOMContentLoaded`** — unloaded background tabs
  don't need to be touched. When the user switches to them, the
  actor child reads current prefs and applies the latest theme.

## What didn't work

- **Data: URIs for actor `esModuleURI` or for sheet registration.**
  Hard crashes. Don't.
- **`loadFrameScript` and other pre-Fission tricks.** Fission is on
  in Zen by default; everything is multi-process now.
- **fx-autoconfig's `@WindowActor` directive** for actors that need
  to attach to web content. The `remoteTypes` it picks are wrong for
  the modern web.
- **The "obvious" CSS template substitution without live reload.**
  Works for first paint, requires Zen restart for every change. The
  whole point of the exercise was *no restart*.
- **Catching `Services.io.newFileURI(chrome://...)`** to find the
  chrome dir. That throws for `chrome://` URIs. Use
  `Services.dirsvc.get("UChrm", Ci.nsIFile)` instead.
- **Single quotes around the `@WindowActorMatches` JSON value.**
  Treated as part of the string by `JSON.parse`. Use double quotes
  or no quotes.

---

## Final architecture

```
┌─────────────────────┐  writes           ┌────────────────────────────┐
│ wabi theme_switcher │ ────────────────► │ chrome/matugen-vars.json   │
│ (Rust binary)       │  8-color JSON     │  {bg, bg_dark, bg_light,   │
└─────────────────────┘                   │   fg, fg_light, accent,    │
        ▲                                │   secondary, tertiary}     │
        │                                └─────────────┬──────────────┘
        │ Quickshell execDetached                      │ polls mtime (1s)
        │                                              ▼
┌─────────────────────┐                   ┌────────────────────────────┐
│ Quickshell bar      │                   │ matugen-bridge.uc.js       │
│ (wallpaper switch)  │                   │ (chrome process)           │
└─────────────────────┘                   │                            │
                                          │ 1. reads JSON              │
                                          │ 2. setStringPref ×8        │
                                          │    (matugen.theme.*)       │
                                          │ 3. apply to :root inline   │
                                          │ 4. broadcast to actors     │
                                          └──────────┬─────────────────┘
                                                     │ sendAsyncMessage
                                                     ▼
                                          ┌────────────────────────────┐
                                          │ MatugenChild.sys.mjs       │
                                          │ (content process)          │
                                          │                            │
                                          │  - DOMContentLoaded:       │
                                          │    read prefs, apply vars  │
                                          │  - Matugen:ApplyVars msg:  │
                                          │    apply vars from bridge  │
                                          └──────────┬─────────────────┘
                                                     │ style.setProperty
                                                     ▼
                                          userContent.css uses
                                          var(--matugen-*) — updates
                                          instantly on inline change
```

Same vars, same theme, both chrome and content. One write to disk
triggers the whole chain.

---

## File map (source → deployed)

| Source | Deployed at | Role |
| --- | --- | --- |
| `.config/zen/userChrome.css.template` | `~/.config/zen/<profile>/chrome/userChrome.css` | Chrome CSS. `:root` block has literal `{{*}}` colors; rules use `var(--matugen-*)`. |
| `.config/zen/userContent.css.template` | `~/.config/zen/<profile>/chrome/userContent.css` | Content CSS. Global `::selection` rule, uses `var(--matugen-*)`. |
| `.config/zen/user.js.template` | `~/.config/zen/<profile>/user.js` | Enables `userChromeJS.experimental.enabled`, `devtools.chrome.enabled`, `toolkit.legacyUserProfileCustomizations.stylesheets`. |
| `.config/zen/fx-autoconfig/profile/chrome/JS/matugen-bridge.uc.js` | same path in profile | The bridge. Polls JSON, sets prefs, applies chrome vars, broadcasts to actors, registers the JSWindowActor. |
| `.config/zen/fx-autoconfig/profile/chrome/JS/Matugen/MatugenParent.sys.mjs` | same path in profile | Parent actor. No-op; required by `ChromeUtils.registerWindowActor`. |
| `.config/zen/fx-autoconfig/profile/chrome/JS/Matugen/MatugenChild.sys.mjs` | same path in profile | Child actor. Sets `var(--matugen-*)` on content `documentElement`. |
| `scripts/theme_switcher` (built) | `~/doty/scripts/theme_switcher` | The deployed Rust binary. wabi/Quickshell runs this on wallpaper change. |
| `.config/hypr/wabi/src/bin/theme/switcher.rs` | builds `target/release/theme_switcher` | Source. Renders templates, copies bridge + actors, writes `matugen-vars.json`, removes legacy files. |

Generated at runtime (not in source):
- `~/.config/zen/<profile>/chrome/matugen-vars.json` — the 8-color JSON.
- `~/.config/zen/<profile>/chrome/matugen-bridge.log` — file-based debug
  log; easier than digging through `console.log` in Browser Toolbox.

---

## How to use it

### Manual theme switch

```bash
cd /home/parazeeknova/doty/.config/hypr/wabi
cargo run --bin theme_switcher -- preset gruvbox
```

This:
1. Renders `userChrome.css.template` and `userContent.css.template` with
   the gruvbox palette, writes them to both profiles.
2. Copies `matugen-bridge.uc.js` and the `Matugen/` actor files into
   both profiles.
3. Writes `matugen-vars.json` with the 8 gruvbox colors.

The bridge picks up the mtime change on its next 1s tick and applies.

### Wallpaper change (the real path)

Quickshell detects wallpaper change → runs
`~/doty/scripts/theme_switcher wallpaper <path>`. The switcher calls
`matugen` against the new wallpaper, gets a fresh palette, runs the
same template/copy/JSON flow.

### Restart Zen

When you actually change `userChrome.css` or `userContent.css` (not
just the colors, but the *rules*), you need to restart Zen — Firefox
only re-reads those files on startup. The bridge handles color
changes at runtime; structural CSS changes need a restart.

### Debugging

```bash
tail -f "/home/parazeeknova/.config/zen/v1oocp83.Default (release)/chrome/matugen-bridge.log"
```

Expected on a healthy theme switch:

```
[matugen-bridge] [INFO] matugen-vars.json mtime changed: ...
[matugen-bridge] [INFO] Wrote 8 prefs from matugen-vars.json
[matugen-bridge] [INFO] Applied 8 vars to chrome :root
[matugen-bridge] [INFO] Broadcast to N/N tab actors (skipped=0)
```

`N/N skipped=0` means every loaded tab got the message. Background
tabs are handled lazily via `DOMContentLoaded` when you switch to them.

For deeper debugging, `Ctrl+Shift+Alt+I` opens the Browser Toolbox
(chrome process console). The bridge also logs to `console.log`
alongside the file log.

---

## Known gotchas (so I don't re-learn them)

1. **`make sync` can fail silently** if any of the deployed binaries
   is busy. Always check `ls -la ~/doty/scripts/theme_switcher` and
   compare to the source `target/release/theme_switcher`. The
   timestamp and size should match.

2. **Fission is on by default in Zen.** No `loadFrameScript`. If you
   want code in content processes, you need a JSWindowActor. Period.

3. **`Services.io.newFileURI(chrome://...)` throws.** Use
   `Services.dirsvc.get("UChrm", Ci.nsIFile)` to get the profile's
   chrome dir.

4. **`@WindowActor` directive in fx-autoconfig is limited.** It
   hardcodes `remoteTypes: ["privilegedabout", null]` — wrong for
   actors that need to attach to web content. Register manually
   with `ChromeUtils.registerWindowActor` instead.

5. **`@WindowActorMatches` is parsed as JSON.** No single quotes.
   `["<all_urls>"]`, not `'["<all_urls>"]'`.

6. **Pref observers fire per `setStringPref`.** If you set 8 prefs in
   a loop, you get 8 observer firings. Suppress the broadcast during
   the batch, then call `onPrefChange()` once at the end.

7. **CSS variables don't cross document boundaries.** Chrome
   `:root` vars are invisible to content. Must use a JSWindowActor
   child to set vars on each content `document.documentElement`.

8. **Inline `style.setProperty` wins over CSS rules.** When the
   bridge sets `documentElement.style.setProperty('--matugen-accent', ...)`,
   it overrides anything in the `:root` block of `userChrome.css` /
   `userContent.css`. That's why the templates can have literal
   first-paint defaults in `:root` — they get clobbered the moment
   the bridge runs.

9. **`currentWindowGlobal` is null for unloaded tabs.** Background
   tabs that haven't been loaded yet don't have a `currentWindowGlobal`,
   so `wg.getActor("Matugen")` returns null for them. The 1/25 ratio
   in the log is normal — the rest pick up the theme via
   `DOMContentLoaded` when you switch to them.

10. **`general.config.sandbox_enabled = false` is no longer needed.**
    fx-autoconfig works without it. Don't add it; it can cause
    weirdness with newer Firefox/Zen builds.

---

## What's still rough

- **No form-control theming in userChrome.css.** I deliberately kept
  the `:root` color tokens off bare `button`, `image`, etc. selectors,
  because those leak to websites and override native HTML form
  controls. If you want checkbox/radio accent, scope it to chrome-only
  ancestors (e.g. `#navigator-toolbox button`).

- **Bridge polls every 1s.** Not free, but cheap. Could be replaced
  with a file watcher (`nsIFileWatcher`) if it ever shows up in
  profiles. Not worth optimizing yet.

- **No de-duplication of color writes.** If wabi writes the exact
  same JSON twice in a row, the bridge still re-applies. The
  `setStringPref` is a no-op for unchanged values (no observer
  fires), so the only wasted work is the mtime check. Fine.

- **Two profiles, double the deployed files.** Could be DRYed with
  symlinks, but symlinks to userChrome.js files in `chrome/JS/` are
  flaky in some Firefox/Zen versions. Just copy.

- **No automation for first-time setup.** If you blow away a profile
  you have to re-run the `sync` target and restart Zen. Not a big
  deal for me, but worth knowing.

---

## Lessons (in case it helps someone else)

1. **If you're fighting the platform, you're probably using the
   wrong mechanism.** The data: URI crash era was me trying to
   outsmart the actor module loader. Prefs are boring; prefs work.

2. **The Fission / multi-process constraint is real.** If you want
   to push values from chrome to content, learn JSWindowActor. It's
   not that hard; it's just not what 2008-era Firefox tutorials teach.

3. **fx-autoconfig is great, but read `boot.sys.mjs` before
   trusting its `@WindowActor` directive.** The defaults it picks
   are wrong for actors that need to attach to web content.

4. **When `make sync` says "nothing to do", it might mean
   "couldn't do it".** Always verify the deployed binary matches
   the source.

5. **Log to a file in the profile dir.** Easier than fishing
   through Browser Toolbox output, survives across restarts,
   easy to grep.

6. **1/25 isn't 0/25.** The actor system is lazy for a reason.
   Don't panic when not every tab shows up in the broadcast log.

---

## TL;DR

- Switcher writes `matugen-vars.json`.
- `matugen-bridge.uc.js` polls it, sets `matugen.theme.*` prefs.
- Bridge sets `--matugen-*` CSS vars on chrome `:root` via inline style.
- Bridge broadcasts to `Matugen` JSWindowActor (registered via
  `ChromeUtils.registerWindowActor` from inside the bridge, NOT via
  fx-autoconfig's `@WindowActor` directive, because that one picks
  wrong `remoteTypes`).
- Child actor sets the same vars on content `documentElement` for
  every loaded tab, and on `DOMContentLoaded` for tabs that load
  later.
- CSS uses `var(--matugen-*)` everywhere. Theme switches live.
- No Zen restart needed for color changes.
