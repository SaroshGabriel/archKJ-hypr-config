#!/bin/bash
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ "$(cat $hwmon/name 2>/dev/null)" = "coretemp" ]; then
        temp=$(cat $hwmon/temp1_input 2>/dev/null)
        if [ -n "$temp" ]; then
            t=$((temp / 1000))
            if [ "$t" -lt 50 ]; then
                class="cool"
            elif [ "$t" -lt 80 ]; then
                class="warm"
            else
                class="critical"
            fi
            echo "{\"text\": \"${t}°C\", \"class\": \"${class}\", \"tooltip\": \"CPU Package Temp: ${t}°C\"}"
            exit 0
        fi
    fi
done
echo "{\"text\": \"N/A\", \"class\": \"unknown\"}"
