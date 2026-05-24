#!/bin/bash
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
mapfile -t walls < <(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \))

_ensure_awww() {
    if ! pgrep -x awww-daemon > /dev/null; then
        awww-daemon &>/dev/null &
        sleep 2
    fi
}

# Set a random wallpaper on every connected output
_set_wallpapers() {
    mapfile -t outputs < <(hyprctl monitors -j 2>/dev/null | python3 -c \
        "import sys,json; [print(m['name']) for m in json.load(sys.stdin)]")
    for output in "${outputs[@]}"; do
        wall="${walls[$RANDOM % ${#walls[@]}]}"
        awww img --outputs "$output" --transition-type fade --transition-duration 2 "$wall" &>/dev/null
    done
}

_ensure_awww

while true; do
    _set_wallpapers
    sleep 300
    _ensure_awww
done
