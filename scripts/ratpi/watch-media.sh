#!/usr/bin/env bash
# watch-media.sh — inotifywait daemon watching organized media dirs on REDACTED
# Triggers jellyfin-scan.sh after DEBOUNCE seconds of quiet following any change.
# Runs as: systemd service (media-watch.service)

set -euo pipefail

TORRENTS="${TORRENTS_DIR:-/mnt/portableUSB256GB}"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="${SCRIPTS}/jellyfin-scan.sh"
DEBOUNCE="${DEBOUNCE:-60}"

WATCH_DIRS=(
    "${TORRENTS}/Movies/Indian"
    "${TORRENTS}/Movies/Foreign"
    "${TORRENTS}/Shows/Indian"
    "${TORRENTS}/Shows/Foreign"
    "${TORRENTS}/Upskill"
)

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') | ${*}"; }

mkdir -p "${WATCH_DIRS[@]}"

log "Media watcher started (DEBOUNCE=${DEBOUNCE}s). Watching:"
for d in "${WATCH_DIRS[@]}"; do log "  $d"; done

while true; do
    changed=$(inotifywait -r -q --format '%w' \
        -e create -e moved_to \
        --exclude '(\.torrent|\.part|\.tmp|\.DS_Store)$' \
        "${WATCH_DIRS[@]}" 2>/dev/null || true)

    log "Change detected in ${changed:-watched dirs}. Waiting ${DEBOUNCE}s for more..."

    while inotifywait -r -q -t "$DEBOUNCE" \
        -e create -e moved_to \
        --exclude '(\.torrent|\.part|\.tmp|\.DS_Store)$' \
        "${WATCH_DIRS[@]}" 2>/dev/null; do
        log "More activity — resetting ${DEBOUNCE}s timer..."
    done

    log "Quiet for ${DEBOUNCE}s — triggering Jellyfin scan."
    "$SCAN" || log "jellyfin-scan.sh exited with error $?"
done
