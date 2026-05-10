#!/bin/bash
cliphist list | head -20 | rofi -dmenu -p "󰆏 Clipboard" -theme ~/.config/rofi/cyberpunk.rasi | cliphist decode | wl-copy
