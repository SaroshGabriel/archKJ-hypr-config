#!/usr/bin/env bash
# lid.sh — clamshell mode handler
# close: if external monitor connected → disable eDP-1; else → lock
# open:  re-enable eDP-1

ACTION="${1:-close}"

_external_connected() {
    hyprctl monitors -j 2>/dev/null | python3 -c \
        "import sys,json; monitors=json.load(sys.stdin); \
         print('yes' if any(m['name']!='eDP-1' for m in monitors) else 'no')" 2>/dev/null
}

case "${ACTION}" in
    close)
        if [[ "$(_external_connected)" == "yes" ]]; then
            # Clamshell: turn off laptop screen, keep working on external
            hyprctl keyword monitor "eDP-1,disable"
        else
            # No external monitor: just lock
            hyprlock
        fi
        ;;
    open)
        # Re-enable laptop screen (no-op if already enabled)
        hyprctl keyword monitor "eDP-1,preferred,0x0,1"
        ;;
esac
