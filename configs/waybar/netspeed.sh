#!/bin/bash
rx1=$(awk 'NR>2{rx+=$2} END{print rx}' /proc/net/dev)
tx1=$(awk 'NR>2{tx+=$10} END{print tx}' /proc/net/dev)
sleep 1
rx2=$(awk 'NR>2{rx+=$2} END{print rx}' /proc/net/dev)
tx2=$(awk 'NR>2{tx+=$10} END{print tx}' /proc/net/dev)

echo "$rx1 $rx2 $tx1 $tx2" | awk '{
    rx=($2-$1)/1024;
    tx=($4-$3)/1024;

    if (rx >= 1024)
        rxstr=sprintf("%.1fM", rx/1024)
    else
        rxstr=sprintf("%.0fK", rx)

    if (tx >= 1024)
        txstr=sprintf("%.1fM", tx/1024)
    else
        txstr=sprintf("%.0fK", tx)

    printf "↓%s ↑%s\n", rxstr, txstr
}'
