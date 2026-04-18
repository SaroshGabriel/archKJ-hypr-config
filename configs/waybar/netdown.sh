#!/bin/bash
rx1=$(awk 'NR>2{rx+=$2} END{print rx}' /proc/net/dev)
sleep 1
rx2=$(awk 'NR>2{rx+=$2} END{print rx}' /proc/net/dev)
echo "$rx1 $rx2" | awk '{
    rx=($2-$1)/1024;
    if (rx >= 1024)
        printf "↓%.1fM\n", rx/1024
    else
        printf "↓%.0fK\n", rx
}'
