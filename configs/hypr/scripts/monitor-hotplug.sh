#!/usr/bin/env bash
# monitor-hotplug.sh — listens to Hyprland IPC and manages external monitor
# on connect: assigns workspaces 11-14, updates waybar external bar output, restarts waybar
# on disconnect: cleans up workspace assignments, restarts waybar

WAYBAR_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/waybar/config.jsonc"
WAYBAR_STYLE="${XDG_CONFIG_HOME:-${HOME}/.config}/waybar/style.css"
HYPR_SCRIPTS="${XDG_CONFIG_HOME:-${HOME}/.config}/hypr/scripts"

_restart_waybar() {
    killall -q waybar
    sleep 0.5
    systemd-cat -t waybar waybar &
}

_on_connect() {
    local mon="${1}"
    [[ "${mon}" == "eDP-1" ]] && return

    # Assign workspaces 11-19 to the new monitor
    for ws in 11 12 13 14 15 16 17 18 19; do
        hyprctl keyword workspace "${ws}, monitor:${mon}" 2>/dev/null
    done
    # Set default workspace on external monitor
    hyprctl keyword workspace "11, monitor:${mon}, default:true" 2>/dev/null

    # Patch the external bar output to the actual monitor name, then restart waybar
    sed -i "s|\"output\": \"[^\"]*\"|\"output\": \"${mon}\"|" \
        <(head -10 "${WAYBAR_CONFIG}") 2>/dev/null || true
    # Use a temp file approach for safety
    local tmp
    tmp=$(mktemp)
    awk -v mon="${mon}" '
        NR==1,/^\{/ { in_first=1 }
        in_first && /"output":/ && !done { sub(/"output": "[^"]*"/, "\"output\": \"" mon "\""); done=1 }
        { print }
    ' "${WAYBAR_CONFIG}" > "${tmp}" && mv "${tmp}" "${WAYBAR_CONFIG}"

    _restart_waybar

    # Set wallpaper on the new monitor
    sleep 1
    bash "${HYPR_SCRIPTS}/../wallpaper.sh" &
}

_on_disconnect() {
    local mon="${1}"
    [[ "${mon}" == "eDP-1" ]] && return

    # Move any workspaces from the removed monitor to eDP-1
    for ws in 11 12 13 14 15 16 17 18 19; do
        hyprctl keyword workspace "${ws}, monitor:eDP-1" 2>/dev/null
    done

    # Restore placeholder output name in config
    local tmp
    tmp=$(mktemp)
    awk '
        NR==1,/^\{/ { in_first=1 }
        in_first && /"output":/ && !done { sub(/"output": "[^"]*"/, "\"output\": \"HDMI-A-1\""); done=1 }
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
