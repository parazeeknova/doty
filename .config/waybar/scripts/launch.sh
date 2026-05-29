#!/bin/bash

if pgrep -x waybar >/dev/null 2>&1; then
  pkill -USR1 -x waybar
else
  waybar &
fi
