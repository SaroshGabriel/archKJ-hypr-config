#!/bin/bash
# Exclude loopback, docker bridges, virtual interfaces
EX="lo:|docker|virbr|br-|veth|tun|tap"

rx1=$(awk -v ex="$EX" 'NR>2 && $1 !~ ex {rx+=$2}  END{print rx+0}' /proc/net/dev)
tx1=$(awk -v ex="$EX" 'NR>2 && $1 !~ ex {tx+=$10} END{print tx+0}' /proc/net/dev)
sleep 1
rx2=$(awk -v ex="$EX" 'NR>2 && $1 !~ ex {rx+=$2}  END{print rx+0}' /proc/net/dev)
tx2=$(awk -v ex="$EX" 'NR>2 && $1 !~ ex {tx+=$10} END{print tx+0}' /proc/net/dev)

echo "$rx1 $rx2 $tx1 $tx2" | awk '{
    rxb=($2-$1); txb=($4-$3)
    rxk=rxb/1024; txk=txb/1024

    if (rxk >= 1024) rxstr=sprintf("%.1fM", rxk/1024)
    else             rxstr=sprintf("%.0fK", rxk)

    if (txk >= 1024) txstr=sprintf("%.1fM", txk/1024)
    else             txstr=sprintf("%.0fK", txk)

    rxmb=rxb/1048576; txmb=txb/1048576
    printf "{\"text\":\"↓%s ↑%s\",\"tooltip\":\"Download: %.3f MB/s\\nUpload: %.3f MB/s\"}\n", rxstr, txstr, rxmb, txmb
}'
