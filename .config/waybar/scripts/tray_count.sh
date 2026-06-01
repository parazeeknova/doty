#!/bin/bash
count=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null | awk '{print $2}')

if [ -z "$count" ] || [ "$count" -eq 0 ]; then
    echo '{"text": "", "class": "empty"}'
else
    echo "{\"text\": \"$count\", \"class\": \"active\"}"
fi
