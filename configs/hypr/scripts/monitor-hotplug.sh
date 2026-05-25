#!/usr/bin/env bash
# monitor-hotplug.sh — listens to Hyprland IPC and manages external monitor
# on connect: assigns workspaces 11-19, patches waybar config (output + persistent-workspaces key)
# on disconnect: rescues windows from external workspaces to laptop (11→1 … 19→9), restores waybar config

WAYBAR_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/waybar/config.jsonc"
HYPR_SCRIPTS="${XDG_CONFIG_HOME:-${HOME}/.config}/hypr/scripts"

_restart_waybar() {
    killall -q waybar
    sleep 2
    systemd-cat -t waybar waybar &
}

_on_connect() {
    local mon="${1}"
    [[ "${mon}" == "eDP-1" ]] && return

    # Assign workspaces 11-19 to the new monitor
    for ws in 11 12 13 14 15 16 17 18 19; do
        hyprctl keyword workspace "${ws}, monitor:${mon}" 2>/dev/null
    done
    hyprctl keyword workspace "11, monitor:${mon}, default:true" 2>/dev/null

    # Patch external bar: top-level "output" field and persistent-workspaces key
    local tmp
    tmp=$(mktemp)
    awk -v mon="${mon}" '
        NR==1,/^\{/ { in_first=1 }
        in_first && /"output":/ && !done_out {
            sub(/"output": "[^"]*"/, "\"output\": \"" mon "\""); done_out=1
        }
        in_first && /"HDMI-A-1": \[/ && !done_pws {
            sub(/"HDMI-A-1"/, "\"" mon "\""); done_pws=1
        }
        { print }
    ' "${WAYBAR_CONFIG}" > "${tmp}" && mv "${tmp}" "${WAYBAR_CONFIG}"

    _restart_waybar

    sleep 1
    bash "${HYPR_SCRIPTS}/../wallpaper.sh" &
}

_on_disconnect() {
    local mon="${1}"
    [[ "${mon}" == "eDP-1" ]] && return

    # Rescue windows from external workspaces to corresponding laptop workspaces (11→1 … 19→9)
    for ws in 11 12 13 14 15 16 17 18 19; do
        local target=$(( ws - 10 ))
        hyprctl clients -j 2>/dev/null \
            | jq -r ".[] | select(.workspace.id == ${ws}) | .address" 2>/dev/null \
            | while read -r addr; do
                hyprctl dispatch movetoworkspacesilent "${target},address:${addr}" 2>/dev/null
              done
    done

    # Restore external bar: top-level "output" placeholder and persistent-workspaces key
    local tmp
    tmp=$(mktemp)
    awk '
        NR==1,/^\{/ { in_first=1 }
        in_first && /"output":/ && !done_out {
            sub(/"output": "[^"]*"/, "\"output\": \"HDMI-A-1\""); done_out=1
        }
        in_first && / *"[^"]*": \[11/ && !done_pws {
            sub(/"[^"]*": \[11/, "\"HDMI-A-1\": [11"); done_pws=1
        }
        { print }
    ' "${WAYBAR_CONFIG}" > "${tmp}" && mv "${tmp}" "${WAYBAR_CONFIG}"

    _restart_waybar
}

# Listen to Hyprland socket2 events
SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

socat -U - "UNIX-CONNECT:${SOCKET}" | while IFS= read -r event; do
    case "${event}" in
        monitoradded\>\>*)
            mon="${event#monitoradded>>}"
            _on_connect "${mon}"
            ;;
        monitorremoved\>\>*)
            mon="${event#monitorremoved>>}"
            _on_disconnect "${mon}"
            ;;
    esac
done
