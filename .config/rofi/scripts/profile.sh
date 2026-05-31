#!/usr/bin/env bash

set -euo pipefail

current_profile=$(asusctl profile get | grep "Active profile" | cut -d' ' -f3 || echo "")

if [ "${ROFI_RETV:-}" = "1" ]; then
    case "${ROFI_INFO:-}" in
        Quiet|Balanced|Performance)
            asusctl profile set "${ROFI_INFO:-}" >/dev/null 2>&1
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "profile: ${ROFI_INFO:-,,}" good 1500
            ;;
    esac
    exit 0
fi

for p in Quiet Balanced Performance; do
    if [ "$p" = "$current_profile" ]; then
        printf '* %s\0info\x1f%s\n' "$p" "$p"
    else
        printf '  %s\0info\x1f%s\n' "$p" "$p"
    fi
done

printf '\0message\x1f%s\n' "$current_profile"
