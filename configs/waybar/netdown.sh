#!/bin/bash
rx1=$(awk 'NR>2{rx+=$2} END{print rx+0}' /proc/net/dev)
sleep 1
rx2=$(awk 'NR>2{rx+=$2} END{print rx+0}' /proc/net/dev)
awk -v r1="$rx1" -v r2="$rx2" 'BEGIN{ printf "↓ %6.2fM\n", (r2-r1)/1048576 }'
