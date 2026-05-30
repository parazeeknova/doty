#!/usr/bin/env bash

set -euo pipefail

SLEEP_TIMER_PID="/tmp/sleep-timer-pid"
SLEEP_TIMER_LABEL="/tmp/sleep-timer-label"

cancel_sleep_timer() {
    if [ -f "$SLEEP_TIMER_PID" ]; then
        local pid
        pid=$(cat "$SLEEP_TIMER_PID")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$SLEEP_TIMER_PID" "$SLEEP_TIMER_LABEL"
    fi
}

set_sleep_timer() {
    local seconds="$1"
    local label="$2"
    cancel_sleep_timer
    ( sleep "$seconds" && systemctl suspend ) &
    echo $! > "$SLEEP_TIMER_PID"
    echo "$label" > "$SLEEP_TIMER_LABEL"
}

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
        timer-15m)
            set_sleep_timer 900 "15 min"
            ;;
        timer-30m)
            set_sleep_timer 1800 "30 min"
            ;;
        timer-1h)
            set_sleep_timer 3600 "1 hr"
            ;;
        timer-2h)
            set_sleep_timer 7200 "2 hr"
            ;;
        timer-cancel)
            cancel_sleep_timer
            ;;
    esac
    exit 0
fi

# Build status message
status="power"
if [ -f "$SLEEP_TIMER_LABEL" ]; then
    label=$(cat "$SLEEP_TIMER_LABEL")
    status="timer: $label"
fi

# Actions
printf 'lock\0info\x1flock\n'
printf 'sleep\0info\x1fsleep\n'
printf 'reboot\0info\x1freboot\n'
printf 'poweroff\0info\x1fpoweroff\n'
printf 'logout\0info\x1flogout\n'

# Timer
if [ -f "$SLEEP_TIMER_LABEL" ]; then
    label=$(cat "$SLEEP_TIMER_LABEL")
    printf 'cancel sleep (%s)\0info\x1ftimer-cancel\n' "$label"
fi
printf 'prevent sleep for 15 min\0info\x1ftimer-15m\n'
printf 'prevent sleep for 30 min\0info\x1ftimer-30m\n'
printf 'prevent sleep for 1 hr\0info\x1ftimer-1h\n'
printf 'prevent sleep for 2 hr\0info\x1ftimer-2h\n'

printf '\0message\x1f%s\n' "$status"
