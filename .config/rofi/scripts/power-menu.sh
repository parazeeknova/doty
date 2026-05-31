#!/usr/bin/env bash

set -euo pipefail

if [ "${ROFI_RETV:-}" = "1" ]; then
    case "${ROFI_INFO:-}" in
        poweroff)
            systemctl poweroff
            ;;
        reboot)
            systemctl reboot
            ;;
        logout)
            hyprctl dispatch 'hl.dsp.exit()' || pkill -x Hyprland
            ;;
        sleep)
            systemctl suspend
            ;;
        lock)
            hyprlock -c ~/.config/hypr/hyprlock.conf
            ;;
    esac
    exit 0
fi

# Actions
printf 'lock\0info\x1flock\n'
printf 'sleep\0info\x1fsleep\n'
printf 'reboot\0info\x1freboot\n'
printf 'poweroff\0info\x1fpoweroff\n'
printf 'logout\0info\x1flogout\n'

printf '\0message\x1fpower\n'
