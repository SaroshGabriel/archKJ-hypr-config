#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
mapfile -t walls < <(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \))

# Ensure daemon is running
if ! pgrep -x awww-daemon > /dev/null; then
    awww-daemon &>/dev/null &
    sleep 3
fi

sleep 2

while true; do
    wall1="${walls[$RANDOM % ${#walls[@]}]}"
    wall2="${walls[$RANDOM % ${#walls[@]}]}"
    awww img --outputs HDMI-A-2 --transition-type fade --transition-duration 2 "$wall1" &>/dev/null
    awww img --outputs eDP-1 --transition-type fade --transition-duration 2 "$wall2" &>/dev/null
    sleep 300
    if ! pgrep -x awww-daemon > /dev/null; then
        awww-daemon &>/dev/null &
        sleep 3
    fi
done
