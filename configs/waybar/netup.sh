#!/bin/bash
tx1=$(awk 'NR>2{tx+=$10} END{print tx+0}' /proc/net/dev)
sleep 1
tx2=$(awk 'NR>2{tx+=$10} END{print tx+0}' /proc/net/dev)
awk -v t1="$tx1" -v t2="$tx2" 'BEGIN{ printf "↑ %6.2fM\n", (t2-t1)/1048576 }'
