#!/usr/bin/env bash

CAFFEINE_FLAG="/tmp/caffeine-mode"

caffeine_is_active() {
    [ -f "$CAFFEINE_FLAG" ]
}

caffeine_toggle() {
    if caffeine_is_active; then
        caffeine_off
    else
        caffeine_on
    fi
}

caffeine_on() {
    if pidof hypridle >/dev/null 2>&1; then
        touch /tmp/caffeine-was-running
        pkill hypridle
    fi
    systemd-inhibit --what=idle:sleep --who=caffeine --why="Caffeine mode" sleep infinity &
    echo $! > "$CAFFEINE_FLAG"
    ~/.config/quickshell/osd/bin/osdctl show "caffeine on" good 1200
}

caffeine_off() {
    rm -f "$CAFFEINE_FLAG"
    pkill -f "systemd-inhibit.*caffeine" 2>/dev/null || true
    if [ ! -f /tmp/caffeine-was-running ]; then
        hypridle &
    fi
    rm -f /tmp/caffeine-was-running
    ~/.config/quickshell/osd/bin/osdctl show "caffeine off" info 1200
}

caffeine_toggle

