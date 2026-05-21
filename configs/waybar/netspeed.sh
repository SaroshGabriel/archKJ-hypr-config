#!/bin/bash
# Streaming netspeed module — emits one JSON line per second with no sampling
# gaps. Run via waybar with restart-interval:5 (no `interval` field).
EX="lo:|docker|virbr|br-|veth|tun|tap"

read_bytes() {
    awk -v ex="$EX" 'NR>2 && $1 !~ ex {rx+=$2; tx+=$10} END{print rx+0, tx+0}' /proc/net/dev
}

read prev_rx prev_tx < <(read_bytes)

while true; do
    sleep 1
    read curr_rx curr_tx < <(read_bytes)

    awk -v p_rx="$prev_rx" -v p_tx="$prev_tx" -v c_rx="$curr_rx" -v c_tx="$curr_tx" 'BEGIN {
        rxb = c_rx - p_rx; txb = c_tx - p_tx
        if (rxb < 0) rxb = 0
        if (txb < 0) txb = 0
        rxk = rxb / 1024; txk = txb / 1024
        if (rxk >= 1024) rxstr = sprintf("%.1fM", rxk / 1024)
        else             rxstr = sprintf("%.0fK", rxk)
        if (txk >= 1024) txstr = sprintf("%.1fM", txk / 1024)
        else             txstr = sprintf("%.0fK", txk)
        rxmb = rxb / 1048576; txmb = txb / 1048576
        printf "{\"text\":\"↓%s ↑%s\",\"tooltip\":\"Download: %.3f MB/s\\nUpload: %.3f MB/s\"}\n", rxstr, txstr, rxmb, txmb
        fflush()
    }'

    prev_rx=$curr_rx
    prev_tx=$curr_tx
done
