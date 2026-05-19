#!/bin/bash
capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
if [[ -z "$capacity" ]]; then
    capacity=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null \
        | awk '/percentage/{gsub(/%/,"",$2); print int($2)}')
fi
status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")

# If capacity is 0 or empty and not actually discharging → battery not detected, show AC
if [[ -z "$capacity" || "$capacity" -eq 0 ]] && [[ "$status" != "Discharging" ]]; then
    printf '{"text":" AC","class":"ac","tooltip":"On AC power\\nBattery not detected"}\n'
    exit 0
fi
capacity=${capacity:-0}

if [[ "$status" == "Charging" ]]; then
    icon="󰂄"; class="charging"
elif [[ $capacity -ge 90 ]]; then icon="󰂃"; class=""
elif [[ $capacity -ge 80 ]]; then icon="󰂂"; class=""
elif [[ $capacity -ge 70 ]]; then icon="󰂁"; class=""
elif [[ $capacity -ge 60 ]]; then icon="󰂀"; class=""
elif [[ $capacity -ge 50 ]]; then icon="󰁿"; class=""
elif [[ $capacity -ge 40 ]]; then icon="󰁾"; class=""
elif [[ $capacity -ge 30 ]]; then icon="󰁽"; class="warning"
elif [[ $capacity -ge 20 ]]; then icon="󰁼"; class="warning"
elif [[ $capacity -ge 10 ]]; then icon="󰁻"; class="critical"
else                                icon="󰁺"; class="critical"
fi

printf '{"text":"%s %d%%","class":"%s","tooltip":"Battery: %d%%\\nStatus: %s"}\n' \
    "$icon" "$capacity" "$class" "$capacity" "$status"
