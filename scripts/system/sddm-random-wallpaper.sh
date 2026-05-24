#!/usr/bin/env bash
# sddm-random-wallpaper.sh — pick a random wallpaper for the SDDM login screen
# Runs as a systemd service before sddm.service on every boot/reboot.

WALLS_DIR="${SDDM_WALLS_DIR:-/home/kj/Pictures/Wallpapers}"
TARGET="/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/current.jpg"

wall=$(find "$WALLS_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \
    -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)

[[ -z "$wall" ]] && { echo "sddm-wallpaper: no wallpapers found in $WALLS_DIR"; exit 0; }

cp -f "$wall" "$TARGET"
chmod 644 "$TARGET"
echo "sddm-wallpaper: set $(basename "$wall")"
