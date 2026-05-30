#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/caffeine.sh"

current_profile=$(asusctl profile get | grep "Active profile" | cut -d' ' -f3 || echo "")

if [ "${ROFI_RETV:-}" = "1" ]; then
    case "${ROFI_INFO:-}" in
        Quiet|Balanced|Performance)
            asusctl profile set "${ROFI_INFO:-}" >/dev/null 2>&1
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "profile: ${ROFI_INFO:-,,}" good 1500
            ;;
        caffeine)
            caffeine_toggle
            ;;
    esac
    exit 0
fi

# Build status message
status="$current_profile"
if caffeine_is_active; then
    status="$current_profile | caffeine: on"
fi

for p in Quiet Balanced Performance; do
    if [ "$p" = "$current_profile" ]; then
        printf '* %s\0info\x1f%s\n' "$p" "$p"
    else
        printf '  %s\0info\x1f%s\n' "$p" "$p"
    fi
done

if caffeine_is_active; then
    printf '* caffeine: on (click to disable)\0info\x1fcaffeine\n'
else
    printf '  caffeine: off (click to enable)\0info\x1fcaffeine\n'
fi

printf '\0message\x1f%s\n' "$status"
