#!/usr/bin/env python3
"""
Waybar Intel iGPU module — streams intel_gpu_top -J at 2s sample interval
and emits one JSON line per sample with usage %, temperature, and per-client
breakdown in the tooltip.

Requires:
  - intel-gpu-tools installed
  - /usr/bin/intel_gpu_top with cap_perfmon+ep (so it runs as user)

Drop-in module config:
  "custom/gpu": {
    "exec": "~/.config/waybar/gpu.sh",
    "return-type": "json",
    "restart-interval": 5
  }
"""
import json
import subprocess
import sys
from pathlib import Path


def find_coretemp():
    for p in sorted(Path("/sys/class/hwmon").iterdir()):
        name_file = p / "name"
        if name_file.exists() and name_file.read_text().strip() == "coretemp":
            return p / "temp1_input"
    return None


def read_temp(temp_file):
    if not temp_file or not temp_file.exists():
        return 0
    try:
        return int(temp_file.read_text().strip()) // 1000
    except (ValueError, OSError):
        return 0


def emit(busy, freq, temp, clients):
    tops = []
    for c in clients.values():
        nm = c.get("name", "?")
        cb = float(c.get("engine-classes", {}).get("Render/3D", {}).get("busy", 0) or 0)
        if cb > 0.5:
            tops.append((cb, nm))
    tops.sort(reverse=True)
    top_lines = "\n".join(f"  {nm}: {b:.0f}%" for b, nm in tops[:6])

    cls = ""
    if busy >= 80:
        cls = "critical"
    elif busy >= 50:
        cls = "warning"

    text = f"\U000f08ae  {int(round(busy))}%  {temp}°"
    tip = f"Intel HD 620\nGPU: {int(round(busy))}% · {int(round(freq))} MHz · {temp}°C"
    if top_lines:
        tip += f"\n\nClients (Render/3D):\n{top_lines}"

    print(json.dumps({"text": text, "tooltip": tip, "class": cls}), flush=True)


def main():
    temp_file = find_coretemp()
    proc = subprocess.Popen(
        ["intel_gpu_top", "-J", "-s", "2000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    buf = ""
    while True:
        chunk = proc.stdout.read1(4096)
        if not chunk:
            break
        buf += chunk.decode("utf-8", errors="replace")
        while True:
            start_idx = buf.find("{")
            if start_idx < 0:
                buf = ""
                break
            depth = 0
            end_idx = -1
            for i in range(start_idx, len(buf)):
                c = buf[i]
                if c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        end_idx = i
                        break
            if end_idx < 0:
                buf = buf[start_idx:]
                break
            try:
                obj = json.loads(buf[start_idx:end_idx + 1])
                busy = float(obj.get("engines", {}).get("Render/3D", {}).get("busy", 0) or 0)
                freq = float(obj.get("frequency", {}).get("actual", 0) or 0)
                clients = obj.get("clients", {}) or {}
                emit(busy, freq, read_temp(temp_file), clients)
            except (json.JSONDecodeError, ValueError, TypeError):
                pass
            buf = buf[end_idx + 1:]

    sys.exit(proc.wait() or 1)


if __name__ == "__main__":
    main()
