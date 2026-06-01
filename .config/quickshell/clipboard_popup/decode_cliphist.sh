#!/bin/bash
# Read top 25 entries from cliphist list
cliphist list | head -n 25 | while read -r line; do
    if echo "$line" | grep -q '\[\[.*binary data.*\]\]'; then
        id=$(echo "$line" | cut -f1)
        if [ ! -f "/tmp/clip_$id.png" ]; then
            echo "$line" | cliphist decode > "/tmp/clip_$id.png" 2>/dev/null
        fi
    fi
done
