#!/usr/bin/env bash
# torrent-sort.sh — interactive categorizer for qBittorrent downloads on REDACTED
# Moves items from TORRENTS root into:
#   Movies/Indian/  Movies/Foreign/  Shows/Indian/  Shows/Foreign/  Upskill/
# Run after torrents finish, or any time to sort new downloads.

set -euo pipefail

TORRENTS="${TORRENTS_DIR:-/mnt/portableUSB256GB}"
MOVIES_IN="${TORRENTS}/Movies/Indian"
MOVIES_FO="${TORRENTS}/Movies/Foreign"
SHOWS_IN="${TORRENTS}/Shows/Indian"
SHOWS_FO="${TORRENTS}/Shows/Foreign"
UPSKILL="${TORRENTS}/Upskill"
INCOMING="${TORRENTS}/Incoming"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENAME_HELPER="${SCRIPTS}/_rename_helper.py"

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
BLU='\033[0;34m'; CYN='\033[0;36m'; BLD='\033[1m'; NC='\033[0m'

hr()  { echo -e "${BLD}${BLU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok()  { echo -e "${GRN}✓ ${*}${NC}"; }
err() { echo -e "${RED}✗ ${*}${NC}"; }

suggest() { python3 "${RENAME_HELPER}" "$1" "$2" 2>/dev/null || echo "$2"; }

ask_region() {
    echo -e "  ${GRN}i${NC}) Indian   ${GRN}f${NC}) Foreign   ${GRN}x${NC}) Skip" >&2
    read -rp "  Region: " r >&2
    echo "${r,,}"
}

ask_name() {
    local suggested="$1"
    echo -e "  Suggested: ${YLW}${suggested}${NC}" >&2
    read -rp "  Name (Enter = accept): " custom >&2
    echo "${custom:-$suggested}"
}

move_movie() {
    local item="$1" raw region dest_dir final_name target
    raw="$(basename "$item")"
    region="$(ask_region)"
    [[ "$region" == "x" ]] && { echo "Skipped."; return; }
    [[ "$region" == "i" ]] && dest_dir="$MOVIES_IN" || dest_dir="$MOVIES_FO"
    final_name="$(ask_name "$(suggest movie "$raw")")"
    target="${dest_dir}/${final_name}"
    if [[ -d "$item" ]]; then
        mkdir -p "${dest_dir}"
        mv -T "$item" "$target" 2>/dev/null || mv "$item" "$target"
        local vf ext new_vf
        vf="$(find "$target" -maxdepth 2 -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \) | head -1)"
        if [[ -n "$vf" ]]; then
            ext="${vf##*.}"; new_vf="${target}/${final_name}.${ext}"
            [[ "$vf" != "$new_vf" ]] && mv "$vf" "$new_vf"
        fi
    else
        mkdir -p "$target"
        local ext="${item##*.}"
        mv "$item" "${target}/${final_name}.${ext}"
    fi
    ok "Moved → ${target}"
}

move_show() {
    local item="$1" raw region dest_dir final_name target
    raw="$(basename "$item")"
    region="$(ask_region)"
    [[ "$region" == "x" ]] && { echo "Skipped."; return; }
    [[ "$region" == "i" ]] && dest_dir="$SHOWS_IN" || dest_dir="$SHOWS_FO"
    final_name="$(ask_name "$(suggest show "$raw")")"
    target="${dest_dir}/${final_name}"
    mkdir -p "${dest_dir}"
    if [[ -d "$item" ]]; then
        mv -T "$item" "$target" 2>/dev/null || mv "$item" "${dest_dir}/${final_name}"
    else
        mkdir -p "$target"; mv "$item" "$target/"
    fi
    ok "Moved → ${target}"
}

move_upskill() {
    local item="$1" raw suggested final_name target
    raw="$(basename "$item")"
    suggested="$(suggest upskill "$raw")"
    final_name="$(ask_name "$suggested")"
    target="${UPSKILL}/${final_name}"
    mkdir -p "${UPSKILL}"
    if [[ -d "$item" ]]; then
        mv -T "$item" "$target" 2>/dev/null || mv "$item" "$target"
    else
        mkdir -p "$target"; mv "$item" "$target/"
    fi
    ok "Moved → ${target}"
}

process_item() {
    local item="$1" name size
    name="$(basename "$item")"
    size="$(du -sh "$item" 2>/dev/null | cut -f1)"
    hr
    echo -e "${BLD}  Item:${NC} ${YLW}${name}${NC}"
    echo -e "  Size: ${size}  |  Type: $( [[ -d "$item" ]] && echo Folder || echo File )"
    echo
    echo -e "  ${GRN}m${NC}) Movie   ${GRN}s${NC}) Show   ${GRN}u${NC}) Upskill   ${GRN}x${NC}) Skip"
    read -rp "  Category: " cat
    case "${cat,,}" in
        m) move_movie   "$item" ;;
        s) move_show    "$item" ;;
        u) move_upskill "$item" ;;
        *) echo "Skipped." ;;
    esac
}

collect_items() {
    local -a items=()
    while IFS= read -r -d '' f; do
        local bname; bname="$(basename "$f")"
        case "$bname" in Movies|Shows|Upskill|Incoming|Downloads|"*.sh"|"*.py"|"*.md") continue ;; esac
        items+=("$f")
    done < <(find "$TORRENTS" -maxdepth 1 -mindepth 1 \
        ! -name "Movies" ! -name "Shows" ! -name "Upskill" \
        ! -name "Incoming" ! -name "Downloads" \
        ! -name "*.sh" ! -name "*.py" ! -name "*.md" \
        -print0 2>/dev/null | sort -z)
    while IFS= read -r -d '' f; do
        items+=("$f")
    done < <(find "$INCOMING" -maxdepth 1 -mindepth 1 -print0 2>/dev/null | sort -z)
    printf '%s\0' "${items[@]}"
}

main() {
    echo -e "\n${BLD}${BLU}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLD}${BLU}║          Torrent Sort — REDACTED                    ║${NC}"
    echo -e "${BLD}${BLU}╚══════════════════════════════════════════════════╝${NC}\n"
    echo -e "Downloads dir: ${CYN}${TORRENTS}${NC}\n"

    mkdir -p "$MOVIES_IN" "$MOVIES_FO" "$SHOWS_IN" "$SHOWS_FO" "$UPSKILL" "$INCOMING"

    local -a items=()
    while IFS= read -r -d '' f; do items+=("$f"); done < <(collect_items)

    if [[ ${#items[@]} -eq 0 ]]; then
        ok "No uncategorized items found. Everything is sorted!"
        exit 0
    fi

    echo -e "Found ${BLD}${#items[@]}${NC} uncategorized item(s).\n"
    for item in "${items[@]}"; do process_item "$item"; echo; done
    hr
    ok "All items processed."
    echo -e "Jellyfin will scan automatically if media-watch.service is running.\n"
}

main "$@"
