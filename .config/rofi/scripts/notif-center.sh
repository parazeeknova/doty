#!/usr/bin/env bash

set -euo pipefail

# Notification center: active notifications + history via mako
command -v jq >/dev/null 2>&1 || exit 0
command -v makoctl >/dev/null 2>&1 || exit 0

shorten() {
    local text=${1:-}
    text=${text//$'\n'/ }
    text=${text//$'\t'/ }
    text=${text//  / }
    printf '%s' "$text"
}

get_field() {
    local json=$1
    local key=$2
    jq -r --arg k "$key" '
        .[$k]
        // .[$k | gsub("-"; "_")]
        // .[$k | gsub("_"; "-")]
        // empty
    ' <<<"$json"
}

emit_items() {
    local source=$1
    local tag=$2
    local json=$3

    jq -c '.[]?' <<<"$json" | while IFS= read -r item; do
        [ -n "$item" ] || continue
        id=$(get_field "$item" id)
        app=$(get_field "$item" app-name)
        [ -n "$app" ] || app="mako"
        summary=$(get_field "$item" summary)
        [ -n "$summary" ] || summary=$(get_field "$item" body)
        [ -n "$summary" ] || summary="(no summary)"
        summary=$(shorten "$summary")
        if [ "$source" = "active" ]; then
            printf '[%s] %s — %s\0info\x1fdismiss:%s\n' "$tag" "$app" "$summary" "$id"
        else
            printf '[%s] %s — %s\0info\x1frestore:%s\n' "$tag" "$app" "$summary" "$id"
        fi
    done
}

# Handle selection
if [ "$#" -gt 0 ]; then
    if [ -n "$ROFI_INFO" ]; then
        if [[ "$ROFI_INFO" == dismiss:* ]]; then
            id="${ROFI_INFO#dismiss:}"
            makoctl dismiss -n "$id"
        elif [[ "$ROFI_INFO" == restore:* ]]; then
            makoctl restore
        elif [[ "$ROFI_INFO" == "clear-all" ]]; then
            makoctl dismiss -a
        fi
    fi
    exit 0
fi

# Active notifications
active=$(makoctl list -j 2>/dev/null)
active_count=$(jq 'length' <<<"${active:-[]}" 2>/dev/null || printf '0')

if [ "$active_count" -gt 0 ]; then
    emit_items active "live" "$active"
fi

# History
history=$(makoctl history -j 2>/dev/null)
history_count=$(jq 'length' <<<"${history:-[]}" 2>/dev/null || printf '0')

if [ "$history_count" -gt 0 ]; then
    emit_items history "hist" "$history"
fi

# Clear all option
printf 'clear all\0info\x1fclear-all\n'

# Bottom label / section footer
printf '\0message\x1fnotifications\n'
