#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -gt 0 ]; then
    case "${ROFI_INFO:-}" in
        poweroff)
            systemctl poweroff
            ;;
        reboot)
            systemctl reboot
            ;;
        logout)
            hyprctl dispatch exit >/dev/null 2>&1 || pkill -x Hyprland
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

printf 'lock\0info\x1flock\n'
printf 'poweroff\0info\x1fpoweroff\n'
printf 'reboot\0info\x1freboot\n'
printf 'logout\0info\x1flogout\n'
printf 'sleep\0info\x1fsleep\n'
printf '\0message\x1fpower\n'
