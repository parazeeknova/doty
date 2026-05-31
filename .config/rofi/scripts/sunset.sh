#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="$HOME/.config/hypr/sunset.state"
CONFIG_FILE="$HOME/.config/hypr/hyprsunset.conf"

# Get current state
current_state="Off"
if [ -f "$STATE_FILE" ]; then
    current_state=$(cat "$STATE_FILE" | tr -d '\n')
fi

clear_config() {
    echo -n "" > "$CONFIG_FILE"
}

write_auto_config() {
    cat <<EOF > "$CONFIG_FILE"
profile {
    time = 08:00
    identity = true
}
profile {
    time = 18:00
    temperature = 5000
}
profile {
    time = 22:00
    temperature = 4000
}
profile {
    time = 06:00
    temperature = 5000
}
EOF
}

restart_sunset() {
    killall hyprsunset >/dev/null 2>&1 || true
    sleep 0.1
    # Run in background
    hyprsunset "$@" >/dev/null 2>&1 &
}

if [ "$#" -gt 0 ]; then
    selection="${ROFI_INFO:-$1}"
    case "$selection" in
        off)
            clear_config
            restart_sunset -i
            echo -n "Off" > "$STATE_FILE"
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset off" info 1200
            ;;
        sunset)
            clear_config
            restart_sunset -t 4500
            echo -n "Sunset" > "$STATE_FILE"
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset 4500k" info 1200
            ;;
        night)
            clear_config
            restart_sunset -t 3500
            echo -n "Night" > "$STATE_FILE"
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset 3500k" info 1200
            ;;
        midnight)
            clear_config
            restart_sunset -t 2500
            echo -n "Midnight" > "$STATE_FILE"
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset 2500k" info 1200
            ;;
        default)
            clear_config
            restart_sunset -t 6000
            echo -n "Default" > "$STATE_FILE"
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset 6000k" info 1200
            ;;
        auto)
            write_auto_config
            restart_sunset
            echo -n "Auto" > "$STATE_FILE"
            # Show what state auto is currently in
            current_hour=$(date +%H)
            if [ "$current_hour" -ge 22 ] || [ "$current_hour" -lt 6 ]; then
                /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset auto: 4000k" info 1200
            elif [ "$current_hour" -ge 18 ] && [ "$current_hour" -lt 22 ]; then
                /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset auto: 5000k" info 1200
            elif [ "$current_hour" -ge 6 ] && [ "$current_hour" -lt 8 ]; then
                /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset auto: 5000k" info 1200
            else
                /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset auto: off" info 1200
            fi
            ;;
        [0-9]*)
            clear_config
            restart_sunset -t "$selection"
            echo -n "$selection" > "$STATE_FILE"
            /home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl show "sunset ${selection}k" info 1200
            ;;
    esac
    exit 0
fi

# List available modes
options=(
    "Auto:auto"
    "Off:off"
    "Default (6000K):default"
    "Sunset (4500K):sunset"
    "Night (3500K):night"
    "Midnight (2500K):midnight"
)

for opt in "${options[@]}"; do
    name="${opt%%:*}"
    key="${opt##*:}"
    clean_name="${name%% (*}"
    if [ "$clean_name" = "$current_state" ] || [ "$name" = "$current_state" ]; then
        printf '* %s\0info\x1f%s\n' "$name" "$key"
    else
        printf '  %s\0info\x1f%s\n' "$name" "$key"
    fi
done

printf '\0message\x1fsunset\n'
