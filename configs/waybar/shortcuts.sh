#!/usr/bin/env bash
# Display Hyprland keybindings in a rofi popup.
# Excludes SUPER+1-9 and ALT+1-9 (raw workspace switches).

CONF="$HOME/.config/hypr/hyprland.conf"

# Escape characters that would break pango markup: & < >  (order matters)
esc() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    printf '%s' "$s"
}

# Pretty-format the dispatcher + args into a human-readable action.
describe() {
    local disp="$1" args="$2"
    case "$disp" in
        exec)             echo "$args" ;;
        killactive)       echo "Close active window" ;;
        exit)             echo "Exit Hyprland" ;;
        fullscreen)       echo "Toggle fullscreen" ;;
        togglefloating)   echo "Toggle floating" ;;
        movefocus)        echo "Focus window${args:+  $args}" ;;
        movewindow)       echo "Move window${args:+  $args}" ;;
        resizewindow)     echo "Resize window (drag)" ;;
        resizeactive)     echo "Resize${args:+  $args}" ;;
        workspace)        echo "Workspace → $args" ;;
        movetoworkspace)  echo "Send window → workspace $args" ;;
        focusmonitor)     echo "Focus monitor${args:+  $args}" ;;
        cyclenext)        [[ -n "$args" ]] && echo "Cycle windows (reverse)" || echo "Cycle windows" ;;
        bringactivetotop) echo "Bring active to top" ;;
        layoutmsg)        echo "Layout: $args" ;;
        *)                echo "$disp${args:+  $args}" ;;
    esac
}

# Format the mods+key column with a fixed width for alignment.
format_keys() {
    local mods="$1" key="$2"
    local combo
    if [[ -n "$mods" ]]; then
        combo="${mods// /+} + ${key}"
    else
        combo="${key}"
    fi
    printf "%-26s" "$combo"
}

current_section=""
output=""

while IFS= read -r raw; do
    # Section header: lines like "# Applications — first-letter mnemonic"
    # (skip pure border lines like "###..." and "###  XYZ  ###")
    if [[ "$raw" =~ ^#[[:space:]]+([^#].*[^#])[[:space:]]*$ ]]; then
        sec="${BASH_REMATCH[1]}"
        sec="${sec##*([[:space:]])}"
        sec="${sec%%*([[:space:]])}"
        if [[ -n "$sec" && ! "$sec" =~ ^[#[:space:]]+$ ]]; then
            current_section="$sec"
            section_pending=1
        fi
        continue
    fi

    # Bind lines (bind, bindel, bindl, bindm)
    if [[ "$raw" =~ ^[[:space:]]*bind(el|l|m)?[[:space:]]*=[[:space:]]*(.*)$ ]]; then
        rest="${BASH_REMATCH[2]}"
        # split by commas
        IFS=',' read -r f1 f2 f3 f4 f5 <<<"$rest"
        mods=$(echo "${f1:-}" | xargs)
        key=$(echo "${f2:-}"  | xargs)
        disp=$(echo "${f3:-}" | xargs)
        # rejoin remaining as args (some dispatchers use commas in args)
        args="${f4:-}"
        [[ -n "$f5" ]] && args="$args,$f5"
        args=$(echo "$args" | xargs)

        # Filter: skip workspace-number bindings (raw + move-to-workspace)
        if [[ "$key" =~ ^[1-9]$ ]]; then
            case "$mods" in
                "SUPER"|"ALT"|"SUPER SHIFT"|"ALT SHIFT")
                    continue
                    ;;
            esac
        fi

        # Mouse buttons — friendlier label
        case "$key" in
            mouse:272)   key="LMB" ;;
            mouse:273)   key="RMB" ;;
            mouse_up)    key="ScrollUp" ;;
            mouse_down)  key="ScrollDown" ;;
        esac

        if [[ -n "$section_pending" ]]; then
            [[ -n "$output" ]] && output+=$'\n'
            output+="<span foreground='#EF3946' weight='bold'>── $(esc "$current_section") ──</span>"$'\n'
            unset section_pending
        fi

        keycol=$(format_keys "$mods" "$key")
        action=$(describe "$disp" "$args")
        output+="  <span foreground='#8be9fd'>$(esc "$keycol")</span>  <span foreground='#cccccc'>$(esc "$action")</span>"$'\n'
    fi
done < "$CONF"

# Show via rofi (dmenu mode — purely informational, ESC to dismiss)
echo -n "$output" | rofi \
    -dmenu \
    -i \
    -markup-rows \
    -p " Hyprland Shortcuts" \
    -theme cyberpunk-popup \
    -theme-str 'listview { lines: 22; }' \
    -no-custom \
    >/dev/null
