#!/bin/bash
# ============================================================
#  archkj-dotfiles — System Ditto Installer
#  Replicates KJ's Arch Linux + Hyprland setup from scratch
#  Usage: bash install.sh
# ============================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME=$(whoami)
HOME_DIR="/home/$USERNAME"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${MAGENTA}[archkj]${NC} $1"; }
ok()      { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${RED}[!]${NC} $1"; }
section() { echo -e "\n${CYAN}══════════════════════════════${NC}\n${CYAN} $1${NC}\n${CYAN}══════════════════════════════${NC}"; }

# ── Pre-flight Checks ────────────────────────────────────────
section "Pre-flight Checks"

if [ "$EUID" -eq 0 ]; then
    warn "Do not run as root. Run as your normal user with sudo access."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    warn "This script is for Arch Linux only."
    exit 1
fi

ok "Running as $USERNAME on Arch Linux"

# ── Install yay ──────────────────────────────────────────────
section "AUR Helper (yay)"

if ! command -v yay &>/dev/null; then
    log "Installing yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay-install
    cd /tmp/yay-install && makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
    ok "yay installed"
else
    ok "yay already present"
fi

# ── Pacman Packages ──────────────────────────────────────────
section "Official Packages (pacman)"

PACMAN_PACKAGES=(
    # Base
    base-devel git sudo vim nano wget unzip tree less
    # Hyprland & Wayland
    hyprland waybar rofi dunst hyprshot awww
    xdg-desktop-portal-hyprland xdg-desktop-portal-kde
    # KDE Plasma
    plasma-desktop plasma-workspace kwin sddm sddm-kcm
    plasma-nm plasma-pa plasma-activities plasma-activities-stats
    bluedevil blueman pavucontrol
    kscreen kscreenlocker kwallet-pam ksshaskpass
    polkit-kde-agent powerdevil plasma-systemmonitor
    kdeplasma-addons kglobalacceld kinfocenter
    breeze breeze-gtk breeze-cursors
    kvantum papirus-icon-theme
    qt5ct layer-shell-qt
    # Terminal & Monitoring
    kitty btop htop s-tui cava
    # Fonts
    ttf-jetbrains-mono-nerd
    # Apps
    firefox thunar libreoffice-fresh telegram-desktop
    vlc mpv gimp imv gwenview spectacle
    deluge deluge-gtk
    # Audio & Codecs
    gst-plugins-ugly gst-plugins-bad gst-libav
    libdvdcss libmad
    # System & Networking
    timeshift networkmanager network-manager-applet
    gnome-keyring ntfs-3g udiskie
    proton-vpn-cli
    # Clipboard
    wl-clipboard cliphist
    # Dev
    python-pip git
    # Misc
    7zip cronie
)

log "Installing pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
ok "Pacman packages done"

# ── AUR Packages ─────────────────────────────────────────────
section "AUR Packages (yay)"

AUR_PACKAGES=(
    brave-bin
    visual-studio-code-bin
    whatsapp-for-linux-git
    networkmanager-dmenu-git
    cliphist
)

log "Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
ok "AUR packages done"

# ── Backup Existing Configs ───────────────────────────────────
section "Backing Up Existing Configs"

BACKUP_DIR="$HOME_DIR/.config-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
for dir in hypr waybar rofi kitty hyprlock; do
    if [ -d "$HOME_DIR/.config/$dir" ]; then
        cp -r "$HOME_DIR/.config/$dir" "$BACKUP_DIR/"
        log "Backed up ~/.config/$dir"
    fi
done
[ -f "$HOME_DIR/.bashrc" ] && cp "$HOME_DIR/.bashrc" "$BACKUP_DIR/bashrc.bak"
ok "Backup saved → $BACKUP_DIR"

# ── Copy Dotfiles ─────────────────────────────────────────────
section "Installing Dotfiles"

for dir in hypr waybar rofi kitty; do
    cp -r "$DOTFILES_DIR/configs/$dir" "$HOME_DIR/.config/"
    ok "~/.config/$dir installed"
done

cp -r "$DOTFILES_DIR/configs/hyprlock" "$HOME_DIR/.config/"
ok "~/.config/hyprlock installed"

cp "$DOTFILES_DIR/configs/bashrc" "$HOME_DIR/.bashrc"
ok "~/.bashrc installed"

# ── Wallpapers ────────────────────────────────────────────────
section "Installing Wallpapers"

mkdir -p "$HOME_DIR/Pictures/Wallpapers"
cp -r "$DOTFILES_DIR/wallpapers/"* "$HOME_DIR/Pictures/Wallpapers/"
ok "Wallpapers → ~/Pictures/Wallpapers ($(ls "$DOTFILES_DIR/wallpapers" | wc -l) files)"

# ── Fix Permissions ───────────────────────────────────────────
section "Setting Permissions"

chmod +x "$HOME_DIR/.config/hypr/wallpaper.sh"
chmod +x "$HOME_DIR/.config/waybar/netspeed.sh"
[ -d "$HOME_DIR/.config/hypr/scripts" ] && chmod +x "$HOME_DIR/.config/hypr/scripts/"*
ok "Permissions set"

# ── Enable Services ───────────────────────────────────────────
section "Enabling System Services"

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable sddm
sudo systemctl enable --now cronie
ok "Services enabled"

# ── Cron: Daily Timeshift ─────────────────────────────────────
section "Timeshift Auto-Snapshot"

(sudo crontab -l 2>/dev/null | grep -v timeshift; echo "0 0 * * * /usr/bin/timeshift --create --scripted") | sudo crontab -
ok "Timeshift daily snapshot at midnight configured"

# ── Done ──────────────────────────────────────────────────────
section "All Done!"

echo -e "${MAGENTA}"
cat << 'EOF'
  ██████╗  ██████╗ ███╗   ██╗███████╗
  ██╔══██╗██╔═══██╗████╗  ██║██╔════╝
  ██║  ██║██║   ██║██╔██╗ ██║█████╗  
  ██║  ██║██║   ██║██║╚██╗██║██╔══╝  
  ██████╔╝╚██████╔╝██║ ╚████║███████╗
  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝
EOF
echo -e "${NC}"
echo -e "${GREEN}archkj dotfiles installed successfully!${NC}\n"
echo -e "Next steps:"
echo -e "  1. ${CYAN}Reboot${NC} your system"
echo -e "  2. ${CYAN}Select Hyprland${NC} in SDDM at login"
echo -e "  3. Sign in to ProtonVPN:  ${CYAN}protonvpn signin <your_email>${NC}"
echo -e "  4. Set up Git:            ${CYAN}git config --global user.name 'Name'${NC}"
echo -e "  5. Read ${CYAN}docs/HDD_MOUNT.md${NC} if you have NTFS drives"
echo ""
