#!/bin/bash
BRAVE_DIR="${HOME}/.config/BraveSoftware/Brave-Browser"
PREF="${BRAVE_DIR}/Default/Preferences"

# Remove stale profile lock left by previous machine
for f in "${BRAVE_DIR}/SingletonLock" "${BRAVE_DIR}/SingletonSocket" "${BRAVE_DIR}/SingletonCookie"; do
    [ -e "$f" ] && rm -f "$f"
done

# Clear crash recovery flag
if [ -f "$PREF" ]; then
    sed -i \
        -e 's/"exited_cleanly":false/"exited_cleanly":true/g' \
        -e 's/"exit_type":"Crashed"/"exit_type":"Normal"/g' \
        "$PREF"
fi
