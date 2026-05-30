#!/usr/bin/env bash

set -euo pipefail

# Handle selection
if [ -n "${1:-}" ]; then
    if [ -n "${ROFI_INFO:-}" ]; then
        # Decode and copy back to clipboard
        cliphist decode "$ROFI_INFO" | wl-copy
    fi
    exit 0
fi

# List cliphist entries
if command -v cliphist &>/dev/null; then
    # We use IFS=$'\t' because cliphist separates id and content with a tab
    cliphist list | while IFS=$'\t' read -r id preview; do
        if [ -z "$id" ]; then
            continue
        fi
        
        # Format preview if it's an image/binary
        if [[ "$preview" =~ ^\[\[\ binary\ data ]]; then
            preview="[image]"
        fi
        
        # Print item for rofi
        printf '%s\0info\x1f%s\n' "$preview" "$id"
    done
fi

printf '\0message\x1fclipboard\n'
