#!/usr/bin/env bash

set -euo pipefail

# Get current profile
current_profile=$(asusctl profile get | grep "Active profile" | cut -d' ' -f3 || echo "")

if [ "$#" -gt 0 ]; then
    profile_to_set="${ROFI_INFO:-}"
    if [ -n "$profile_to_set" ]; then
        asusctl profile set "$profile_to_set" >/dev/null 2>&1
        # Show on OSD
        /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "profile: ${profile_to_set,,}" good 1500
    fi
    exit 0
fi

# List available profiles
for p in Quiet Balanced Performance; do
    if [ "$p" = "$current_profile" ]; then
        printf '* %s\0info\x1f%s\n' "$p" "$p"
    else
        printf '  %s\0info\x1f%s\n' "$p" "$p"
    fi
done

printf '\0message\x1fprofile\n'
