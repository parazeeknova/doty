#!/usr/bin/env bash

# Recents: show running apps with workspace, switch on select
# Convert number to Roman numeral
to_roman() {
    local num=$1
    local roman=""
    local values=(10 9 5 4 1)
    local symbols=("x" "ix" "v" "iv" "i")
    
    for i in "${!values[@]}"; do
        while ((num >= values[i])); do
            roman+="${symbols[i]}"
            ((num -= values[i]))
        done
    done
    echo "$roman"
}

# Get focused monitor name
get_focused_monitor() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name'
}

# Handle selection
if [ -n "$1" ]; then
    if [ -n "$ROFI_INFO" ] && [[ "$ROFI_INFO" == ws:* ]]; then
        ws="${ROFI_INFO#ws:}"
        hyprctl dispatch "hl.dsp.focus({workspace=$ws})" >/dev/null 2>&1
    fi
    exit 0
fi

# List running windows from Hyprland
if command -v hyprctl &> /dev/null; then
    current_title=""
    current_workspace=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^Window\ [0-9a-fA-F]+\ -\>\ (.+): ]]; then
            current_title="${BASH_REMATCH[1]}"
            current_workspace=""
        elif [[ "$line" =~ workspace:\ ([0-9]+) ]]; then
            current_workspace="${BASH_REMATCH[1]}"
            if [ -n "$current_title" ] && [ -n "$current_workspace" ]; then
                roman=$(to_roman "$current_workspace")
                printf '[%s] %s\0info\x1fws:%s\n' "$roman" "$current_title" "$current_workspace"
                current_title=""
                current_workspace=""
            fi
        fi
    done < <(hyprctl clients 2>/dev/null)
fi
