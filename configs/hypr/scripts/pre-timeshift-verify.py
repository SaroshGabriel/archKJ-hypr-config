#!/usr/bin/env python3
# ============================================================
#  pre-timeshift-verify.py — System Health Check
#  Works on any machine — uses $HOME, not hardcoded paths.
# ============================================================
import subprocess
import os
import socket
import datetime
from pathlib import Path

HOME = Path.home()
REPORT_DIR = HOME / "Logs" / "preTimeshift"
timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
report_path = REPORT_DIR / f"preTimeshiftReport_{timestamp}.log"
REPORT_DIR.mkdir(parents=True, exist_ok=True)


def run(cmd):
    try:
        env = os.environ.copy()
        env["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10, env=env)
        return r.stdout.strip() or r.stderr.strip() or "OK"
    except Exception:
        return "TIMEOUT/ERROR"


def read_k10temp():
    for hwmon in sorted(Path("/sys/class/hwmon").iterdir()):
        name_f = hwmon / "name"
        if name_f.exists() and name_f.read_text().strip() == "k10temp":
            temp_f = hwmon / "temp1_input"
            if temp_f.exists():
                return str(round(int(temp_f.read_text().strip()) / 1000, 1))
    return "N/A"


def check_file(path): return "✅ EXISTS" if Path(path).exists() else "❌ MISSING"
def check_dir(path):  return "✅ EXISTS" if Path(path).is_dir()  else "❌ MISSING"
def svc_active(name): return "✅ active"  if run(f"systemctl is-active {name}")  == "active"  else "❌ inactive"
def svc_enabled(name):return "✅ enabled" if run(f"systemctl is-enabled {name}") == "enabled" else "❌ disabled"


r = []
r.append("=" * 60)
r.append("PRE-TIMESHIFT VERIFICATION REPORT")
r.append(f"Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
r.append(f"Host:       {socket.gethostname()}")
r.append("=" * 60)

# ── System ───────────────────────────────────────────────────
r.append("\n[ SYSTEM ]")
r.append(f"Kernel:             {run('uname -r')}")
r.append(f"Uptime:             {run('uptime -p')}")
r.append(f"CPU Temp:           {read_k10temp()}°C")
r.append(f"Disk / (root):      {run('df -h / | tail -1')}")
r.append(f"Disk /mnt/Data:     {run('df -h /mnt/Data | tail -1')}")
r.append(f"Disk /mnt/Movies:   {run('df -h /mnt/Movies | tail -1')}")
r.append(f"RAM:                {run('free -h | grep Mem')}")
r.append(f"Failed Services:    {run('systemctl --failed --no-legend | wc -l')} failed")
r.append(f"Orphan packages:    {run('pacman -Qdt 2>/dev/null | wc -l')} orphans")

# ── Security ─────────────────────────────────────────────────
r.append("\n[ SECURITY ]")
r.append(f"SSH PermitRootLogin:{run('grep PermitRootLogin /etc/ssh/sshd_config | head -1')}")
r.append(f"SSH daemon:         {svc_active('sshd')}")
r.append(f"Tailscale:          {svc_active('tailscaled')}")

# ── Hyprland ─────────────────────────────────────────────────
r.append("\n[ HYPRLAND ]")
cfg = HOME / ".config"
r.append(f"hyprland.conf:      {check_file(cfg / 'hypr' / 'hyprland.conf')}")
r.append(f"hypridle.conf:      {check_file(cfg / 'hypr' / 'hypridle.conf')}")
r.append(f"hyprlock.conf:      {check_file(cfg / 'hyprlock' / 'hyprlock.conf')}")
r.append(f"wallpaper.sh:       {check_file(cfg / 'hypr' / 'wallpaper.sh')}")
r.append(f"fix-brave.sh:       {check_file(cfg / 'hypr' / 'fix-brave.sh')}")
r.append(f"WLR_DRM_DEVICES:    {run(f'grep WLR_DRM_DEVICES {cfg}/hypr/hyprland.conf')}")
r.append(f"Monitors:           {run('hyprctl monitors 2>/dev/null | grep Monitor || echo not running')}")
r.append(f"awww-daemon:        {'✅ YES' if run('pgrep awww-daemon') else '❌ NOT RUNNING'}")

# ── Waybar ───────────────────────────────────────────────────
r.append("\n[ WAYBAR ]")
r.append(f"config.jsonc:       {check_file(cfg / 'waybar' / 'config.jsonc')}")
r.append(f"style.css:          {check_file(cfg / 'waybar' / 'style.css')}")
r.append(f"battery.sh:         {check_file(cfg / 'waybar' / 'battery.sh')}")
r.append(f"gpu.sh:             {check_file(cfg / 'waybar' / 'gpu.sh')}")
r.append(f"cpu.sh:             {check_file(cfg / 'waybar' / 'cpu.sh')}")
r.append(f"Waybar running:     {'✅ YES' if run('pgrep waybar') else '❌ NOT RUNNING'}")

# ── Kitty / Rofi ─────────────────────────────────────────────
r.append("\n[ KITTY / ROFI ]")
r.append(f"kitty.conf:         {check_file(cfg / 'kitty' / 'kitty.conf')}")
r.append(f"rofi config.rasi:   {check_file(cfg / 'rofi' / 'config.rasi')}")
r.append(f"powermenu.sh:       {check_file(cfg / 'rofi' / 'powermenu.sh')}")

# ── Services ─────────────────────────────────────────────────
r.append("\n[ SERVICES ]")
r.append(f"NetworkManager:     {svc_active('NetworkManager')}")
r.append(f"SDDM:               {svc_enabled('sddm')}")
r.append(f"Bluetooth:          {svc_active('bluetooth')}")
r.append(f"SSH:                {svc_active('sshd')}")
r.append(f"Tailscale:          {svc_active('tailscaled')}")

# ── Storage ──────────────────────────────────────────────────
r.append("\n[ STORAGE ]")
r.append(f"lsblk:              {run('lsblk -o NAME,SIZE,MOUNTPOINT | grep -v loop')}")
r.append(f"/mnt/Data mounted:  {'✅ YES' if run('mountpoint -q /mnt/Data && echo yes') == 'yes' else '❌ NOT MOUNTED'}")
r.append(f"/mnt/Movies:        {'✅ YES' if run('mountpoint -q /mnt/Movies && echo yes') == 'yes' else '❌ NOT MOUNTED'}")

# ── LinuxScripts / niftyMonitor ──────────────────────────────
r.append("\n[ LINUX SCRIPTS ]")
r.append(f"LinuxScripts/:      {check_dir(HOME / 'LinuxScripts')}")
r.append(f"niftyMonitor venv:  {check_dir(HOME / 'LinuxScripts' / 'niftyMonitor' / '.venv')}")
r.append(f"nifty CSV files:    {run(f'ls {HOME}/Data/niftyMonitor/*.csv 2>/dev/null | wc -l')} files")

# ── Git / SSH ────────────────────────────────────────────────
r.append("\n[ GIT / SSH ]")
r.append(f"Git user:           {run('git config --global user.name')}")
r.append(f"SSH id_ed25519:     {check_file(HOME / '.ssh' / 'id_ed25519')}")
r.append(f"SSH REDACTED:          {check_file(HOME / '.ssh' / 'REDACTED')}")
r.append(f"GitHub connect:     {run('ssh -T git@github.com 2>&1')}")

# ── Wallpapers ───────────────────────────────────────────────
r.append("\n[ WALLPAPERS ]")
r.append(f"Total wallpapers:   {run(f'find {HOME}/Pictures/Wallpapers -type f 2>/dev/null | wc -l')}")

# ── Installed Apps ───────────────────────────────────────────
r.append("\n[ INSTALLED APPS ]")
for app in ['hyprland', 'waybar', 'kitty', 'rofi', 'dunst', 'hypridle', 'hyprlock',
            'hyprshot', 'brightnessctl', 'playerctl', 'udiskie', 'tailscale',
            'brave-bin', 'firefox', 'telegram-desktop', 'thunar']:
    result = run(f"pacman -Q {app} 2>/dev/null")
    status = f"✅ {result}" if result and "error" not in result.lower() else "❌ NOT INSTALLED"
    r.append(f"  {app:30s} {status}")

r.append("\n" + "=" * 60)
r.append("END OF REPORT")
r.append("=" * 60)

output = '\n'.join(r)
with open(report_path, 'w') as f:
    f.write(output)

print(output)
print(f"\nReport saved → {report_path}")
