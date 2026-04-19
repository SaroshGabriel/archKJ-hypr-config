#!/bin/bash
tx1=$(awk 'NR>2{tx+=$10} END{print tx}' /proc/net/dev)
sleep 1
tx2=$(awk 'NR>2{tx+=$10} END{print tx}' /proc/net/dev)
echo "$tx1 $tx2" | awk '{
    tx=($2-$1)/1024;
    if (tx >= 1024)
        printf "↑%7.2fM\n", tx/1024
    else
        printf "↑%7.2fK\n", tx
}'
