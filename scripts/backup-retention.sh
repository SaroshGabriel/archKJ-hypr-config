#!/usr/bin/env bash
# backup-retention.sh — prune homelab backup snapshots on archmac
# Retention: 12 weeklies + 6 monthlies
# Usage: backup-retention.sh <WEEK_TAG>
# Example: backup-retention.sh 2026-W22

set -euo pipefail

WEEK_TAG="${1:-}"
ROOT="${BACKUP_ROOT:-/mnt/Data/homelab-backups}"
INCOMING="$ROOT/incoming"
WEEKLIES="$ROOT/weekly"
MONTHLIES="$ROOT/monthly"
LOG="${LOG_FILE:-$HOME/Logs/backup-retention.log}"

log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }

mkdir -p "$(dirname "$LOG")"

[[ -n "$WEEK_TAG" ]] || { log "FATAL: missing WEEK_TAG arg (e.g. 2026-W22)"; exit 1; }
[[ -d "$INCOMING/$WEEK_TAG" ]] || { log "FATAL: $INCOMING/$WEEK_TAG not found"; exit 1; }

mkdir -p "$WEEKLIES" "$MONTHLIES"

log "=== retention run for $WEEK_TAG ==="

# Promote incoming → weekly
[[ -d "$WEEKLIES/$WEEK_TAG" ]] && rm -rf "$WEEKLIES/$WEEK_TAG"
mv "$INCOMING/$WEEK_TAG" "$WEEKLIES/$WEEK_TAG"
log "promoted to weekly: $WEEKLIES/$WEEK_TAG"

# First weekly of the month → also snapshot to monthlies
MONTH_TAG=$(date -u +%Y-%m)
if [[ ! -d "$MONTHLIES/$MONTH_TAG" ]]; then
    cp -r "$WEEKLIES/$WEEK_TAG" "$MONTHLIES/$MONTH_TAG"
    log "month-boundary: copied to $MONTHLIES/$MONTH_TAG"
fi

# Prune: keep last 12 weeklies + last 6 monthlies
log "pruning weeklies (keep 12)..."
ls -dt "$WEEKLIES"/*/ 2>/dev/null | tail -n +13 | xargs -r rm -rf
log "pruning monthlies (keep 6)..."
ls -dt "$MONTHLIES"/*/ 2>/dev/null | tail -n +7 | xargs -r rm -rf

USAGE=$(du -sh "$ROOT" | cut -f1)
log "total $ROOT usage: $USAGE"
log "=== done ==="
