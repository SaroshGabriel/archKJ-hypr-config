#!/usr/bin/env python3
# ============================================================
#  pre-timeshift-verify.py — archkj System Health Check
#  Author: KJ / SaroshGabriel
#  Updated: 2026-04-18 (post full system audit)
# ============================================================
import subprocess
import os
import datetime

# ── Config ───────────────────────────────────────────────────
HOME = "/home/KJ"
REPORT_DIR = f"{HOME}/Logs/preTimeshift"
timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
report_path = f"{REPORT_DIR}/preTimeshiftReport_{timestamp}.log"
os.makedirs(REPORT_DIR, exist_ok=True)

# ── Helpers ──────────────────────────────────────────────────
def run(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return r.stdout.strip() or r.stderr.strip() or "OK"
    except:
        return "TIMEOUT/ERROR"

def check_file(path):
    return "✅ EXISTS" if os.path.exists(path) else "❌ MISSING"

def check_dir(path):
    return "✅ EXISTS" if os.path.isdir(path) else "❌ MISSING"

def svc_active(name):
    return "✅ active" if run(f"systemctl is-active {name}") == "active" else "❌ inactive"

def svc_enabled(name):
    return "✅ enabled" if run(f"systemctl is-enabled {name}") == "enabled" else "❌ disabled"

def pkg(name):
    result = run(f"pacman -Q {name} 2>/dev/null")
    return f"✅ {result}" if result and "error" not in result.lower() else "❌ NOT INSTALLED"

# ── Report ───────────────────────────────────────────────────
r = []

r.append("=" * 60)
r.append("PRE-TIMESHIFT VERIFICATION REPORT")
r.append(f"Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
r.append("=" * 60)

# ── System ───────────────────────────────────────────────────
r.append("\n[ SYSTEM ]")
r.append(f"Hostname:           {run('hostname')}")
r.append(f"Kernel:             {run('uname -r')}")
r.append(f"Uptime:             {run('uptime -p')}")
temp_raw = run("cat /sys/class/thermal/thermal_zone0/temp")
temp_c = str(round(int(temp_raw) / 1000, 1)) if temp_raw.isdigit() else "N/A"
r.append(f"CPU Temp:           {temp_c}°C")
r.append(f"CPU Governor:       {run('cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor')}")
r.append(f"Disk / (SSD):       {run('df -h / | tail -1')}")
r.append(f"Disk HDD1:          {run('df -h /mnt/HDD1 | tail -1')}")
r.append(f"Disk HDD2:          {run('df -h /mnt/HDD2 | tail -1')}")
r.append(f"RAM:                {run('free -h | grep Mem')}")
r.append(f"Failed Services:    {run('systemctl --failed --no-legend | wc -l')} failed")
r.append(f"Orphan packages:    {run('pacman -Qdt 2>/dev/null | wc -l')} orphans")

# ── Security ─────────────────────────────────────────────────
r.append("\n[ SECURITY ]")
r.append(f"Nouveau blacklist:  {check_file('/etc/modprobe.d/blacklist-nouveau.conf')}")
r.append(f"SSH PermitRootLogin:{run('grep PermitRootLogin /etc/ssh/sshd_config | head -1')}")
r.append(f"Samba guest access: {run('grep \"guest ok\" /etc/samba/smb.conf | head -1')}")
r.append(f"SSH daemon:         {svc_active('sshd')}")
r.append(f"Samba daemon:       {svc_active('smb')}")
r.append(f"ProtonVPN:          {svc_active('proton.VPN')}")
r.append(f"Tailscale:          {svc_active('tailscaled')}")

# ── Hyprland ─────────────────────────────────────────────────
r.append("\n[ HYPRLAND ]")
r.append(f"hyprland.conf:      {check_file(f'{HOME}/.config/hypr/hyprland.conf')}")
r.append(f"hypridle.conf:      {check_file(f'{HOME}/.config/hypr/hypridle.conf')}")
r.append(f"hyprlock.conf:      {check_file(f'{HOME}/.config/hyprlock/hyprlock.conf')}")
r.append(f"wallpaper.sh:       {check_file(f'{HOME}/.config/hypr/wallpaper.sh')}")
r.append(f"fix-brave.sh:       {check_file(f'{HOME}/.config/hypr/fix-brave.sh')}")
r.append(f"launch-nifty.sh:    {check_file(f'{HOME}/.config/hypr/scripts/launch-nifty.sh')}")
r.append(f"pre-timeshift.py:   {check_file(f'{HOME}/.config/hypr/scripts/pre-timeshift-verify.py')}")
r.append(f"WLR_DRM_DEVICES:    {run('grep WLR_DRM_DEVICES /home/KJ/.config/hypr/hyprland.conf')}")
r.append(f"Monitors:           {run('hyprctl monitors | grep Monitor')}")
r.append(f"awww-daemon:        {'✅ YES' if run('pgrep awww-daemon') else '❌ NOT RUNNING'}")

# ── Waybar ───────────────────────────────────────────────────
r.append("\n[ WAYBAR ]")
r.append(f"config.jsonc:       {check_file(f'{HOME}/.config/waybar/config.jsonc')}")
r.append(f"style.css:          {check_file(f'{HOME}/.config/waybar/style.css')}")
r.append(f"netspeed.sh:        {check_file(f'{HOME}/.config/waybar/netspeed.sh')}")
r.append(f"clock.sh:           {check_file(f'{HOME}/.config/waybar/clock.sh')}")
r.append(f"battery.sh:         {check_file(f'{HOME}/.config/waybar/battery.sh')}")
r.append(f"Waybar running:     {'✅ YES' if run('pgrep waybar') else '❌ NOT RUNNING'}")

# ── Kitty ────────────────────────────────────────────────────
r.append("\n[ KITTY ]")
r.append(f"kitty.conf:         {check_file(f'{HOME}/.config/kitty/kitty.conf')}")
r.append(f"cursor_blink:       {run('grep cursor_blink_interval /home/KJ/.config/kitty/kitty.conf')}")
r.append(f"repaint_delay:      {run('grep repaint_delay /home/KJ/.config/kitty/kitty.conf')}")

# ── Rofi ─────────────────────────────────────────────────────
r.append("\n[ ROFI ]")
r.append(f"config.rasi:        {check_file(f'{HOME}/.config/rofi/config.rasi')}")
r.append(f"cyberpunk.rasi:     {check_file(f'{HOME}/.config/rofi/cyberpunk.rasi')}")
r.append(f"powermenu.sh:       {check_file(f'{HOME}/.config/rofi/powermenu.sh')}")
r.append(f"Modes:              {run('grep modes /home/KJ/.config/rofi/config.rasi')}")

# ── Dunst ────────────────────────────────────────────────────
r.append("\n[ DUNST ]")
r.append(f"dunstrc:            {check_file(f'{HOME}/.config/dunst/dunstrc')}")
r.append(f"Dunst running:      {'✅ YES' if run('pgrep dunst') else '❌ NOT RUNNING'}")

# ── XDG Portal ───────────────────────────────────────────────
r.append("\n[ XDG PORTAL ]")
r.append(f"portal config:      {check_file(f'{HOME}/.config/xdg-desktop-portal/hyprland-portals.conf')}")

# ── Brave ────────────────────────────────────────────────────
r.append("\n[ BRAVE ]")
r.append(f"brave-flags.conf:   {check_file(f'{HOME}/.config/brave-flags.conf')}")
r.append(f"HW accel disabled:  {run('grep disable-gpu /home/KJ/.config/brave-flags.conf | head -1')}")

# ── SDDM ─────────────────────────────────────────────────────
r.append("\n[ SDDM ]")
r.append(f"SDDM:               {svc_enabled('sddm')}")
r.append(f"Theme config:       {check_file('/etc/sddm.conf.d/theme.conf')}")

# ── Services ─────────────────────────────────────────────────
r.append("\n[ SERVICES ]")
r.append(f"NetworkManager:     {svc_active('NetworkManager')}")
nm_wait = svc_enabled('NetworkManager-wait-online')
nm_status = "✅ correctly disabled" if "disabled" in nm_wait else "⚠️ should be disabled"
r.append(f"NM-wait-online:     {nm_status}")
r.append(f"Bluetooth:          {svc_active('bluetooth')}")
r.append(f"Cronie:             {svc_active('cronie')}")
r.append(f"cpupower:           {svc_enabled('cpupower')}")
r.append(f"Timeshift cron:     {run('sudo crontab -l 2>/dev/null | grep timeshift')}")

# ── Storage ──────────────────────────────────────────────────
r.append("\n[ STORAGE ]")
r.append(f"SSD (sda):          {run('lsblk /dev/sda -o NAME,SIZE,MOUNTPOINT | grep -v loop')}")
r.append(f"HDD (sdb):          {run('lsblk /dev/sdb -o NAME,SIZE,MOUNTPOINT | grep -v loop')}")
r.append(f"HDD1 mounted:       {'✅ YES' if run('mountpoint -q /mnt/HDD1 && echo yes') == 'yes' else '❌ NOT MOUNTED'}")
r.append(f"HDD2 mounted:       {'✅ YES' if run('mountpoint -q /mnt/HDD2 && echo yes') == 'yes' else '❌ NOT MOUNTED'}")
r.append(f"Torrents dir:       {check_dir(f'{HOME}/Downloads/Torrents')}")
r.append(f"HDD2 Torrents:      {check_dir('/mnt/HDD2/Torrents')}")

# ── DFT Setup ────────────────────────────────────────────────
r.append("\n[ DFT SETUP ]")
r.append(f"DFT folder:         {check_dir(f'{HOME}/Projects/dft')}")
r.append(f"Python venv:        {check_dir(f'{HOME}/Projects/dft/dft-env')}")
r.append(f"dft-fundamentals:   {check_dir(f'{HOME}/Projects/dft/dft-fundamentals')}")
r.append(f"bsr-cell:           {check_dir(f'{HOME}/Projects/dft/bsr-cell')}")
r.append(f"atpg-python-tool:   {check_dir(f'{HOME}/Projects/dft/atpg-python-tool')}")
r.append(f"dft-readiness:      {check_dir(f'{HOME}/Projects/dft/dft-readiness-checker')}")
r.append(f"openroad-dft-flow:  {check_dir(f'{HOME}/Projects/dft/openroad-dft-flow')}")
r.append(f"DFT Roadmap:        {check_file(f'{HOME}/Projects/dft/DFT_Roadmap.md')}")

# ── LinuxScripts ─────────────────────────────────────────────
r.append("\n[ LINUX SCRIPTS ]")
r.append(f"LinuxScripts/:      {check_dir(f'{HOME}/LinuxScripts')}")
r.append(f"niftyMonitor/:      {check_dir(f'{HOME}/LinuxScripts/niftyMonitor')}")
r.append(f"stock_monitor.py:   {check_file(f'{HOME}/LinuxScripts/niftyMonitor/stock_monitor.py')}")
r.append(f"niftyMonitor venv:  {check_dir(f'{HOME}/LinuxScripts/niftyMonitor/.venv')}")
r.append(f"aliasSyncWithBashrc:{check_dir(f'{HOME}/LinuxScripts/aliasSyncWithBashrc')}")
r.append(f"waybarConfig:       {check_dir(f'{HOME}/LinuxScripts/waybarConfig')}")
r.append(f"setupWorkspace.sh:  {check_file(f'{HOME}/LinuxScripts/setupWorkspace.sh')}")
r.append(f"Nifty data dir:     {check_dir(f'{HOME}/Data/niftyMonitor')}")

# ── Git ──────────────────────────────────────────────────────
r.append("\n[ GIT ]")
r.append(f"Git user:           {run('git config --global user.name')}")
r.append(f"Git email:          {run('git config --global user.email')}")
r.append(f"SSH key:            {check_file(f'{HOME}/.ssh/id_ed25519')}")
r.append(f"GitHub connect:     {run('ssh -T git@github.com 2>&1')}")
r.append(f"dotfiles repo:      {check_dir(f'{HOME}/archkj-dotfiles/.git')}")
r.append(f"LinuxScripts repo:  {check_dir(f'{HOME}/LinuxScripts/.git')}")

# ── Installed Apps ───────────────────────────────────────────
r.append("\n[ INSTALLED APPS ]")
apps = [
    'hyprland', 'waybar', 'kitty', 'rofi', 'dunst',
    'brave-bin', 'firefox', 'telegram-desktop',
    'vlc', 'vlc-plugin-ffmpeg', 'deluge', 'timeshift',
    'btop', 'htop', 'code', 'thunar', 'libreoffice-fresh',
    'whatsapp-for-linux', 'cpupower', 'tailscale',
    'udiskie', 'brightnessctl', 'playerctl', 'hyprshot',
]
for app in apps:
    result = run(f"pacman -Q {app} 2>/dev/null")
    status = f"✅ {result}" if result and "error" not in result.lower() else "❌ NOT INSTALLED"
    r.append(f"  {app:30s} {status}")

# ── Wallpapers ───────────────────────────────────────────────
r.append("\n[ WALLPAPERS ]")
r.append(f"Total wallpapers:   {run('find /home/KJ/Pictures/Wallpapers -type f 2>/dev/null | wc -l')}")
r.append(f"awww-daemon:        {'✅ RUNNING' if run('pgrep awww-daemon') else '❌ NOT RUNNING'}")

# ── Logs ─────────────────────────────────────────────────────
r.append("\n[ LOGS ]")
r.append(f"preTimeshift logs:  {run('ls /home/KJ/Logs/preTimeshift/ | wc -l')} files")
r.append(f"nifty CSV files:    {run('ls /home/KJ/Data/niftyMonitor/*.csv 2>/dev/null | wc -l')} files")

r.append("\n" + "=" * 60)
r.append("END OF REPORT")
r.append("=" * 60)

# ── Output ───────────────────────────────────────────────────
output = '\n'.join(r)
with open(report_path, 'w') as f:
    f.write(output)

print(f"Running pre-Timeshift verification...")
print(f"Report saved to: {report_path}")
print(output)
print()
