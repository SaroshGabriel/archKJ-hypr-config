#!/usr/bin/env bash
# jellyfin-scan.sh — trigger a full Jellyfin library refresh
# Called by watch-media.sh after media is sorted into organized folders.

set -euo pipefail

JELLYFIN_API="${JELLYFIN_API:-http://localhost:8096}"
ENV_FILE="${HOME}/.config/homelab.env"
LOCK="${TMPDIR:-/tmp}/jellyfin-scan.lock"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') | ${*}"; }

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
[[ -n "${JELLYFIN_KEY:-}" ]] || { log "ERROR: JELLYFIN_KEY not set (check ${ENV_FILE})"; exit 1; }

if [[ -f "$LOCK" ]]; then
    pid="$(cat "$LOCK" 2>/dev/null)"
    kill -0 "$pid" 2>/dev/null && { log "Scan already running (PID $pid). Skipping."; exit 0; }
    rm -f "$LOCK"
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

log "Triggering Jellyfin library scan..."
http_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    "${JELLYFIN_API}/Library/Refresh?api_key=${JELLYFIN_KEY}" 2>/dev/null)

if [[ "$http_code" == "204" ]]; then
    log "Jellyfin scan triggered successfully (HTTP 204)"
else
    log "Jellyfin responded: HTTP ${http_code}"
fi
