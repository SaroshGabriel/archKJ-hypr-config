#!/usr/bin/env python3
"""
Waybar AMD iGPU module — reads Vega iGPU stats from sysfs.
Dynamically locates the correct hwmon by PCI slot (card2 / 0000:04:00.0).

Emits one JSON line per INTERVAL seconds with frequency, temperature,
and current P-state in the tooltip.
"""
import json
import time
from pathlib import Path

INTERVAL = 2.0


def find_edp_pci_slot():
    """Return PCI slot of whichever card drives the built-in eDP display."""
    for entry in sorted(Path("/sys/class/drm").iterdir()):
        if "-eDP" not in entry.name:
            continue
        card = entry.name.split("-")[0]
        uevent = Path(f"/sys/class/drm/{card}/device/uevent")
        if uevent.exists():
            for line in uevent.read_text().splitlines():
                if line.startswith("PCI_SLOT_NAME="):
                    return line.split("=", 1)[1]
    return None


def find_igpu_hwmon():
    pci_slot = find_edp_pci_slot()
    if not pci_slot:
        return None
    for hwmon in sorted(Path("/sys/class/hwmon").iterdir()):
        name_f = hwmon / "name"
        uevent_f = hwmon / "device" / "uevent"
        if not name_f.exists() or name_f.read_text().strip() != "amdgpu":
            continue
        if uevent_f.exists() and pci_slot in uevent_f.read_text():
            return hwmon
    return None


def read_int(path):
    try:
        return int(Path(path).read_text().strip())
    except (ValueError, OSError):
        return 0


def read_pstate(card_path):
    """Parse pp_dpm_sclk — return (active_mhz, all_states_str)."""
    sclk = card_path / "pp_dpm_sclk"
    if not sclk.exists():
        return 0, ""
    lines = sclk.read_text().strip().splitlines()
    active_mhz = 0
    states = []
    for line in lines:
        active = line.endswith("*")
        parts = line.rstrip(" *").split()
        if len(parts) >= 2:
            mhz_str = parts[1].rstrip("Mhz")
            try:
                mhz = int(mhz_str)
            except ValueError:
                mhz = 0
            states.append(f"  {'▶' if active else ' '} {parts[1]}")
            if active:
                active_mhz = mhz
    return active_mhz, "\n".join(states)


def main():
    hwmon = find_igpu_hwmon()
    pci_slot = find_edp_pci_slot()
    card_dev = None
    if pci_slot:
        for entry in sorted(Path("/sys/class/drm").iterdir()):
            if "-" in entry.name:
                continue
            uevent = entry / "device" / "uevent"
            if uevent.exists() and pci_slot in uevent.read_text():
                card_dev = entry / "device"
                break

    while True:
        temp = 0
        freq_mhz = 0
        pstate_str = ""

        if hwmon:
            temp = read_int(hwmon / "temp1_input") // 1000
            freq_hz = read_int(hwmon / "freq1_input")
            freq_mhz = freq_hz // 1_000_000

        # pp_dpm_sclk gives a more readable P-state view
        if card_dev.exists():
            active_mhz, pstate_str = read_pstate(card_dev)
            if active_mhz:
                freq_mhz = active_mhz

        cls = ""
        if temp >= 85:
            cls = "critical"
        elif temp >= 70:
            cls = "warning"

        text = f"\U000f1515  {freq_mhz} MHz  {temp}°"
        tip = f"AMD Vega iGPU\n{freq_mhz} MHz · {temp}°C"
        if pstate_str:
            tip += f"\n\nP-states:\n{pstate_str}"

        print(json.dumps({"text": text, "tooltip": tip, "class": cls}), flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
