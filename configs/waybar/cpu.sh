#!/usr/bin/env python3
"""
Waybar CPU module — emits one JSON line every INTERVAL seconds with CPU
usage %, package temperature, and top processes in the tooltip.

Mirrors the format of gpu.sh.

Drop-in module config:
  "custom/cpu": {
    "exec": "~/.config/waybar/cpu.sh",
    "return-type": "json",
    "restart-interval": 5,
    "tooltip": true
  }
"""
import json
import subprocess
import time
from pathlib import Path

INTERVAL = 2.0  # seconds — matches gpu.sh cadence


def find_coretemp():
    for p in sorted(Path("/sys/class/hwmon").iterdir()):
        n = p / "name"
        if n.exists() and n.read_text().strip() == "coretemp":
            return p / "temp1_input"
    return None


def read_temp(f):
    if not f or not f.exists():
        return 0
    try:
        return int(f.read_text().strip()) // 1000
    except (ValueError, OSError):
        return 0


def read_cpu_stat():
    # /proc/stat first line: cpu user nice system idle iowait irq softirq steal guest guest_nice
    with open("/proc/stat") as fh:
        parts = fh.readline().split()
    nums = [int(x) for x in parts[1:8]]
    idle = nums[3] + nums[4]  # idle + iowait
    total = sum(nums)
    return total, idle


def read_freq_mhz():
    freqs = []
    for p in sorted(Path("/sys/devices/system/cpu").glob("cpu[0-9]*/cpufreq/scaling_cur_freq")):
        try:
            freqs.append(int(p.read_text().strip()))
        except (ValueError, OSError):
            pass
    if not freqs:
        return 0
    return sum(freqs) / len(freqs) / 1000  # kHz → MHz


def read_loadavg():
    try:
        return open("/proc/loadavg").read().split()[:3]
    except OSError:
        return ["?", "?", "?"]


def top_processes(n=6):
    try:
        out = subprocess.check_output(
            ["ps", "-eo", "pcpu=,comm=", "--sort=-pcpu"],
            text=True, timeout=1,
        )
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        return []
    rows = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        try:
            pcpu = float(parts[0])
        except ValueError:
            continue
        if pcpu > 0.5:
            rows.append((pcpu, parts[1]))
        if len(rows) >= n:
            break
    return rows


def main():
    temp_file = find_coretemp()
    prev_total, prev_idle = read_cpu_stat()

    while True:
        time.sleep(INTERVAL)
        total, idle = read_cpu_stat()
        dt = total - prev_total
        di = idle - prev_idle
        prev_total, prev_idle = total, idle

        usage = 0.0
        if dt > 0:
            usage = max(0.0, min(100.0, (1.0 - di / dt) * 100.0))

        t = read_temp(temp_file)
        freq = read_freq_mhz()
        load = read_loadavg()
        tops = top_processes()
        top_lines = "\n".join(f"  {nm}: {p:.0f}%" for p, nm in tops)

        cls = ""
        if usage >= 80:
            cls = "critical"
        elif usage >= 50:
            cls = "warning"

        text = f"\U000F0EE0  {int(round(usage))}%  {t}°"
        tip = (
            f"CPU\n"
            f"Usage: {int(round(usage))}% · {int(round(freq))} MHz · {t}°C\n"
            f"Load (1/5/15m): {load[0]}  {load[1]}  {load[2]}"
        )
        if top_lines:
            tip += f"\n\nTop processes:\n{top_lines}"

        print(json.dumps({"text": text, "tooltip": tip, "class": cls}), flush=True)


if __name__ == "__main__":
    main()
