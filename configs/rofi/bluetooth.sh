#!/usr/bin/env bash
# Bluetooth menu — bluetoothctl + rofi, cyberpunk-popup themed.
# Top level: power toggle, scan toggle, device list.
# Per-device: connect/disconnect, trust/untrust, pair/remove.

ROFI=(rofi -dmenu -i -markup-rows -theme cyberpunk-popup -no-custom)

icon_power_on="󰂯"
icon_power_off="󰂲"
icon_dot_on="<span foreground='#50fa7b'>●</span>"
icon_dot_off="<span foreground='#555566'>○</span>"
header() {
    printf "<span foreground='#EF3946' weight='bold'>── %s ──</span>" "$1"
}

power_state() {
    bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}'
}

scan_state() {
    bluetoothctl show 2>/dev/null | awk -F': ' '/Discovering:/ {print $2; exit}'
}

device_connected() {
    bluetoothctl info "$1" 2>/dev/null | awk -F': ' '/Connected:/ {print $2; exit}'
}

device_paired() {
    bluetoothctl info "$1" 2>/dev/null | awk -F': ' '/Paired:/ {print $2; exit}'
}

device_trusted() {
    bluetoothctl info "$1" 2>/dev/null | awk -F': ' '/Trusted:/ {print $2; exit}'
}

device_menu() {
    local mac="$1" name="$2"
    local conn paired trusted
    conn=$(device_connected "$mac")
    paired=$(device_paired "$mac")
    trusted=$(device_trusted "$mac")

    local opts=()
    opts+=("$(header "$name")")
    if [[ "$conn" == "yes" ]]; then
        opts+=("󰂰  Disconnect")
    else
        opts+=("󰂱  Connect")
    fi
    if [[ "$trusted" == "yes" ]]; then
        opts+=("󰚌  Untrust")
    else
        opts+=("󰚊  Trust")
    fi
    if [[ "$paired" == "yes" ]]; then
        opts+=("󰆴  Remove")
    else
        opts+=("󰌹  Pair")
    fi
    opts+=("󰜉  Back")

    local choice
    choice=$(printf '%s\n' "${opts[@]}" | "${ROFI[@]}" -p " $name")
    case "$choice" in
        *Disconnect) bluetoothctl disconnect "$mac" >/dev/null ;;
        *Connect)    bluetoothctl connect "$mac"    >/dev/null ;;
        *Untrust)    bluetoothctl untrust "$mac"    >/dev/null ;;
        *Trust)      bluetoothctl trust "$mac"      >/dev/null ;;
        *Pair)       bluetoothctl pair "$mac"       >/dev/null ;;
        *Remove)     bluetoothctl remove "$mac"     >/dev/null ;;
        *Back)       main_menu ;;
    esac
}

main_menu() {
    local pwr scn
    pwr=$(power_state)
    scn=$(scan_state)

    local opts=()
    # name→MAC map for selection lookup (parallel arrays, indexed by display text)
    declare -A name_to_mac
    opts+=("$(header "Bluetooth")")
    if [[ "$pwr" == "yes" ]]; then
        opts+=("${icon_power_on}  Power: <span foreground='#50fa7b'>on</span>")
    else
        opts+=("${icon_power_off}  Power: <span foreground='#555566'>off</span>")
    fi
    if [[ "$pwr" == "yes" ]]; then
        if [[ "$scn" == "yes" ]]; then
            opts+=("󰓦  Scan: <span foreground='#50fa7b'>scanning…</span>")
        else
            opts+=("󰓦  Scan for devices")
        fi
        opts+=("$(header "Devices")")
        while IFS=' ' read -r _ mac name; do
            [[ -z "$mac" ]] && continue
            local dot
            if [[ "$(device_connected "$mac")" == "yes" ]]; then
                dot="$icon_dot_on"
            else
                dot="$icon_dot_off"
            fi
            local row="${dot}  ${name}"
            opts+=("$row")
            name_to_mac["$row"]="$mac|||$name"
        done < <(bluetoothctl devices 2>/dev/null)
    fi

    local choice
    choice=$(printf '%s\n' "${opts[@]}" | "${ROFI[@]}" \
        -p " Bluetooth" \
        -theme-str 'listview { lines: 10; }')

    case "$choice" in
        ""|*"── "*) ;;  # cancel or header row
        *"Power:"*on*)
            bluetoothctl power off >/dev/null
            main_menu ;;
        *"Power:"*off*)
            bluetoothctl power on >/dev/null
            main_menu ;;
        *"Scan: "*scanning*)
            bluetoothctl --timeout 1 scan off >/dev/null 2>&1 &
            main_menu ;;
        *"Scan for devices")
            (bluetoothctl --timeout 10 scan on >/dev/null 2>&1) &
            sleep 0.4
            main_menu ;;
        *)
            local pair="${name_to_mac[$choice]}"
            if [[ -n "$pair" ]]; then
                local mac="${pair%%|||*}"
                local dname="${pair#*|||}"
                device_menu "$mac" "$dname"
            fi ;;
    esac
}

main_menu
