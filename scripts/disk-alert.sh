#!/usr/bin/env bash
# disk-alert.sh — monitor local drives on archmac, send Telegram alert when thresholds crossed
# Runs via systemd timer (hourly). Silent when healthy; alerts on warn/critical.

set -euo pipefail

WARN_PCT="${WARN_PCT:-85}"
CRIT_PCT="${CRIT_PCT:-93}"
ALERT_FLAG_DIR="${TMPDIR:-/tmp}/disk-alert-flags"
MACHINE="${MACHINE:-$(cat /etc/hostname 2>/dev/null || echo archmac)}"

declare -A DISKS=(
    ["Root"]="/"
    ["Data"]="/mnt/Data"
    ["Movies"]="/mnt/Movies"
)

TELEGRAM_TOKEN="$(pass homelab/telegram_bot_token 2>/dev/null)" \
    || { echo "ERROR: cannot read telegram_bot_token from pass"; exit 1; }
TELEGRAM_CHAT_ID="$(pass homelab/telegram_chat_id 2>/dev/null)" \
    || { echo "ERROR: cannot read telegram_chat_id from pass"; exit 1; }

mkdir -p "$ALERT_FLAG_DIR"

tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="$1" \
        -d parse_mode="HTML" \
        -o /dev/null
}

for label in "${!DISKS[@]}"; do
    mount="${DISKS[$label]}"
    flag="$ALERT_FLAG_DIR/${MACHINE}_${label}.flag"

    if ! mountpoint -q "$mount" 2>/dev/null && [[ "$mount" != "/" ]]; then
        if [[ ! -f "$flag" ]]; then
            tg_send "⚠️ <b>${MACHINE} disk alert</b>
<b>${label}</b> is not mounted at ${mount}."
            touch "$flag"
        fi
        continue
    fi

    used_pct=$(df "$mount" | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    avail_h=$(df -h "$mount" | awk 'NR==2{print $4}')

    if (( used_pct >= CRIT_PCT )); then
        if [[ ! -f "${flag}.crit" ]]; then
            tg_send "🔴 <b>${MACHINE} CRITICAL</b>
<b>${label}</b> is ${used_pct}% full (${avail_h} free).
Action needed now — free space before writes fail."
            touch "${flag}.crit"
        fi
    elif (( used_pct >= WARN_PCT )); then
        if [[ ! -f "$flag" ]]; then
            tg_send "🟡 <b>${MACHINE} disk warning</b>
<b>${label}</b> is ${used_pct}% full (${avail_h} free).
Consider freeing space soon."
            touch "$flag"
        fi
    else
        rm -f "$flag" "${flag}.crit"
    fi
done
