#!/usr/bin/env bash
# Launch fastfetch with an Arch logo AND a "Charge In Motion" header that both
# size to the current terminal window — so nothing clips in narrow/split panes
# and it looks full in a maximized window.

src="$HOME/.config/fastfetch/config.jsonc"
command -v fastfetch >/dev/null 2>&1 || exit 0
[ -f "$src" ] || exit 0

# Current terminal width (cols). Prefer live $COLUMNS, fall back to tput.
cols="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"

# Logo width: ~38% of the window, clamped.
w=$(( cols * 38 / 100 ))
(( w < 18 )) && w=18
(( w > 60 )) && w=60

# Width left for the info/header column (window minus logo minus padding).
info=$(( cols - w - 8 ))
(( info < 10 )) && info=10

# Pick a header + rule that fit the info column.
#   spaced  (~37 cols) for roomy windows
#   compact (~21 cols) for medium
#   tiny    (~13 cols) for very narrow split panes
if   (( info >= 38 )); then
  header="[ C H A R G E   I N   M O T I O N ]"
  rule="───────────────────────────────────"
elif (( info >= 22 )); then
  header="[ CHARGE IN MOTION ]"
  rule="─────────────────────"
else
  header="CHARGE·IN·MOTION"
  rule="────────────────"
fi

# Render a runtime config with the chosen header/rule substituted in.
tmp="$(mktemp --suffix=.jsonc 2>/dev/null || echo "/tmp/ff-cim.$$.jsonc")"
trap 'rm -f "$tmp"' EXIT
sed -e "s/__HEADER__/${header}/" -e "s/__RULE__/${rule}/" "$src" > "$tmp"

fastfetch --config "$tmp" --logo-width "$w" 2>/dev/null
