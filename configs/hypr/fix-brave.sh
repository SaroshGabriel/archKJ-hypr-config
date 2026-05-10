#!/bin/bash
PREF="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
if [ -f "$PREF" ]; then
    sed -i \
        -e 's/"exited_cleanly":false/"exited_cleanly":true/g' \
        -e 's/"exit_type":"Crashed"/"exit_type":"Normal"/g' \
        "$PREF"
fi
