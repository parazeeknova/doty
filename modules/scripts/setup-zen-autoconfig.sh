#!/usr/bin/env bash
# One-time system install for fx-autoconfig on Zen Browser.
# Enables chrome/JS/zen-reload.uc.js (and any other .uc.js) to load at startup.
#
# Requires sudo. Run once:
#   sudo scripts/setup-zen-autoconfig.sh
# or:
#   make setup-zen-autoconfig

set -euo pipefail

ZEN_APP="/opt/zen-browser-bin"

# Resolve the original user's home (works correctly under sudo where $HOME=/root)
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="$HOME"
fi

DOTY_DIR="${DOTY_DIR:-$USER_HOME/doty}"
AUTOCFG_SRC="$DOTY_DIR/.config/zen/fx-autoconfig/program"

if [[ ! -d "$ZEN_APP" ]]; then
  echo "Zen install not found at $ZEN_APP" >&2
  exit 1
fi

if [[ ! -f "$AUTOCFG_SRC/config.js" ]]; then
  echo "fx-autoconfig source not found at $AUTOCFG_SRC" >&2
  echo "Resolved DOTY_DIR=$DOTY_DIR (SUDO_USER=${SUDO_USER:-none})" >&2
  exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

echo "Installing fx-autoconfig into $ZEN_APP ..."
install -m 644 "$AUTOCFG_SRC/config.js" "$ZEN_APP/config.js"
install -m 644 "$AUTOCFG_SRC/defaults/pref/config-prefs.js" "$ZEN_APP/defaults/pref/config-prefs.js"

echo "Done. Restart Zen for changes to take effect."
echo "After restart, check Browser Toolbox console for:"
echo "  [zen-reload] Watching: /home/.../chrome/userChrome.css"
