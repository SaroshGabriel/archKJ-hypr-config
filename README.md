# archkj-dotfiles

> 🔴 Arch Linux + **Hyprland** system — clone and replicate in one script.

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat)
![Waybar](https://img.shields.io/badge/Waybar-EF3946?style=flat)

A cyberpunk red/pink rice: full Wayland desktop config plus the helper scripts
and systemd units that drive it. Multi-host aware — the same configs run on the
archKJ workstation and the archmac laptop.

---

## What's included

| Category | Details |
|---|---|
| **WM** | Hyprland — dual-monitor workspaces, hypridle, hyprlock |
| **Bar** | Waybar — per-monitor bars; cpu/gpu/battery/netspeed/clipboard modules |
| **Launcher** | Rofi (cyberpunk theme) + wifi / bluetooth / powermenu menus |
| **Terminal** | Kitty, JetBrainsMono Nerd Font |
| **Shell** | Bash — aliases auto-sync to running docker services |
| **Login** | SDDM (astronaut theme) + Sekiro GRUB theme |
| **Thermals** | `thermal-guardian` service + disk-alert timer |
| **Backups** | Timeshift snapshots + retention script |

**Theme:** background `#32111C`, accent `#EF3946`.

---

## Install

```bash
git clone https://github.com/SaroshGabriel/archkj-dotfiles.git
cd archkj-dotfiles
bash install.sh          # installs packages, symlinks configs, enables services
```

Package lists live in `docs/pacman-packages.txt` and `docs/aur-packages.txt`.
After install: reboot, pick **Hyprland** at SDDM. NTFS drives → `docs/HDD_MOUNT.md`.

---

## Layout

```
install.sh                 Bootstrap: packages + symlinks + services
collect.sh                 Pull live configs back into the repo
setup-github.sh            Git/SSH setup helper
configs/
  bashrc                   Shell config (labmap auto-syncs to docker services)
  hypr/                    hyprland.conf, hypridle, scripts (wallpaper, lid,
                           monitor-hotplug, pre-timeshift-verify, fix-brave)
  hyprlock/  kitty/  rofi/ Lock screen, terminal, launcher (+ wifi/bt/power menus)
  waybar/                  config.jsonc, style.css, module scripts
  sddm/  grub/             Login + boot themes
  systemd-system/          thermal-guardian, sddm-wallpaper units
  systemd-user/            disk-alert timer/service
  environment.d/  networkmanager-dmenu/
scripts/
  thermal-guardian.sh  disk-alert.sh  backup-retention.sh
  system/sddm-random-wallpaper.sh
  ratpi/                   Helpers that target the Pi (media sort/scan/watch)
docs/                      HDD_MOUNT.md, pacman/aur package lists
wallpapers/                124 wallpapers
```

---

## Branches

- **`main`** — primary, machine-agnostic configs (this branch).
- **`archmac`** — archmac laptop-specific tweaks (per-monitor bars, brightness module, slim autostart).

---

## Notes

- **Hardware auto-detect:** `gpu.sh` finds the iGPU via the active eDP output
  (no hard-coded PCI slot), so the same config works on both machines.
- `hypridle` staggers lock/DPMS and suspends at 30 min.
- ProtonVPN / credentials are **not** stored in this repo.
- **Large repo (~1 GB) — it's the wallpapers.** Configs-only checkout:
  ```bash
  git clone --filter=blob:none --sparse https://github.com/SaroshGabriel/archkj-dotfiles.git
  cd archkj-dotfiles && git sparse-checkout set configs scripts docs
  ```
