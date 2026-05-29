#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -gt 0 ]; then
    case "${ROFI_INFO:-}" in
        poweroff)
            if command -v hyprshutdown &>/dev/null; then
                hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff'
            else
                systemctl poweroff
            fi
            ;;
        reboot)
            if command -v hyprshutdown &>/dev/null; then
                hyprshutdown -t 'Restarting...' --post-cmd 'systemctl reboot'
            else
                systemctl reboot
            fi
            ;;
        logout)
            if command -v hyprshutdown &>/dev/null; then
                hyprshutdown -t 'Logging out...'
            else
                hyprctl dispatch exit >/dev/null 2>&1 || pkill -x Hyprland
            fi
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
