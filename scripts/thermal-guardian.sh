#!/usr/bin/env bash
# thermal-guardian.sh — AMD CPU temperature watchdog for archmac (Ryzen 5 2500U)
# Sensors: k10temp Tctl (CPU die), schedutil <-> powersave governor swap
#
# Install: sudo bash ~/scripts/thermal-guardian.sh --install
# Logs:    journalctl -t thermal-guardian -f
# Status:  systemctl status thermal-guardian

TEMP_HIGH="${TEMP_HIGH:-85}"   # °C — engage throttle (Tctl)
TEMP_SAFE="${TEMP_SAFE:-75}"   # °C — restore normal (hysteresis)
POLL_SEC="${POLL_SEC:-5}"

SCRIPT_DST="/usr/local/bin/thermal-guardian.sh"
SERVICE_DST="/etc/systemd/system/thermal-guardian.service"
LOG_TAG="thermal-guardian"
NOTIFY_USER="${NOTIFY_USER:-${SUDO_USER:-kj}}"
NOTIFY_UID=$(id -u "$NOTIFY_USER" 2>/dev/null || echo "1000")

# ── Install mode ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--install" ]]; then
    [[ "$EUID" -ne 0 ]] && { echo "Run as root: sudo bash $0 --install"; exit 1; }

    cp "$0" "$SCRIPT_DST"
    chmod +x "$SCRIPT_DST"

    cat > "$SERVICE_DST" << 'EOF'
[Unit]
Description=Thermal Guardian — AMD CPU throttle watchdog
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/thermal-guardian.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now thermal-guardian.service
    echo "[✓] thermal-guardian installed and active"
    echo "    Monitor: journalctl -t thermal-guardian -f"
    echo "    Status:  systemctl status thermal-guardian"
    exit 0
fi

# ── Find k10temp Tctl sensor ──────────────────────────────────────────────────
_find_temp_file() {
    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ "$(cat "$hwmon/name" 2>/dev/null)" == "k10temp" ]] || continue
        local f="$hwmon/temp1_input"
        [[ -r "$f" ]] && echo "$f" && return
    done
}

_get_temp() {
    [[ -r "$TEMP_FILE" ]] || { echo 0; return; }
    echo $(( $(cat "$TEMP_FILE") / 1000 ))
}

_set_governor() {
    local g="$1"
    for pol in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
        [[ -w "$pol" ]] && echo "$g" > "$pol"
    done
}

# AMD CPU boost: 1=enabled, 0=disabled
_set_boost() {
    local boost_f="/sys/devices/system/cpu/cpufreq/boost"
    [[ -f "$boost_f" ]] && echo "$1" > "$boost_f"
}

_notify() {
    local urgency="$1" title="$2" body="$3"
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${NOTIFY_UID}/bus" \
        sudo -u "$NOTIFY_USER" notify-send -u "$urgency" -t 5000 "$title" "$body" 2>/dev/null || true
}

# ── Init ──────────────────────────────────────────────────────────────────────
TEMP_FILE=$(_find_temp_file)

if [[ -z "$TEMP_FILE" ]]; then
    logger -t "$LOG_TAG" "ERROR: k10temp sensor not found — aborting"
    exit 1
fi

logger -t "$LOG_TAG" "Started — sensor: $TEMP_FILE | throttle: >${TEMP_HIGH}°C | restore: <${TEMP_SAFE}°C | poll: ${POLL_SEC}s"

throttling=false

# ── Main loop ─────────────────────────────────────────────────────────────────
while true; do
    temp=$(_get_temp)

    if (( temp >= TEMP_HIGH )) && [[ "$throttling" == false ]]; then
        throttling=true
        _set_governor powersave
        _set_boost 0
        logger -t "$LOG_TAG" "THROTTLE ON  — ${temp}°C >= ${TEMP_HIGH}°C | governor: powersave | boost: off"
        _notify critical "🌡️ Thermal Guardian" "${temp}°C — throttling active\nPowersave mode, boost off"

    elif (( temp < TEMP_SAFE )) && [[ "$throttling" == true ]]; then
        throttling=false
        _set_boost 1
        _set_governor schedutil
        logger -t "$LOG_TAG" "THROTTLE OFF — ${temp}°C < ${TEMP_SAFE}°C | governor: schedutil | boost: on"
        _notify normal "🌡️ Thermal Guardian" "${temp}°C — cooled, performance restored"
    fi

    sleep "$POLL_SEC"
done
