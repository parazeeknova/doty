#!/bin/bash

# Toggle the glass/blur state
STATE_FILE="/tmp/quickshell_glass_state"
CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "true")

if [ "$CURRENT_STATE" = "true" ]; then
    NEW_STATE="false"
    OPACITY="1.0"
    INACTIVE_OPACITY="1.0"
    BLUR="false"
    OSD_STATUS="Off"
    OSD_COLOR="bad"
    # Make Waybar and Rofi opaque
    sed -i 's/background-color: alpha(@bg0, 0.75);/background-color: @bg0;/g' ~/.config/waybar/style.css
    sed -i 's/bg0:     #1d202180;/bg0:     #1d2021;/g' ~/.config/rofi/theme.rasi
else
    NEW_STATE="true"
    OPACITY="0.85"
    INACTIVE_OPACITY="0.75"
    BLUR="true"
    OSD_STATUS="On"
    OSD_COLOR="good"
    # Make Waybar and Rofi transparent
    sed -i 's/background-color: @bg0;/background-color: alpha(@bg0, 0.75);/g' ~/.config/waybar/style.css
    sed -i 's/bg0:     #1d2021;/bg0:     #1d202180;/g' ~/.config/rofi/theme.rasi
fi

# Apply state via hyprctl eval
hyprctl eval "hl.config({ decoration = { active_opacity = $OPACITY, inactive_opacity = $INACTIVE_OPACITY, blur = { enabled = $BLUR } } })"

# Save state
echo "$NEW_STATE" > "$STATE_FILE"

# Show OSD
~/doty/.config/quickshell/osd/bin/osdctl show "Glass: $OSD_STATUS" "$OSD_COLOR" 1200

# Reload Waybar
pkill -x waybar
sleep 0.1
waybar >/dev/null 2>&1 &
