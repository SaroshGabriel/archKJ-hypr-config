#!/usr/bin/env bash
# Thin rofi wrapper for networkmanager_dmenu — applies the shared
# cyberpunk-popup theme with a wifi-sized listview.
exec rofi -dmenu -theme cyberpunk-popup -theme-str 'listview { lines: 12; }' "$@"
