#!/bin/bash
# ============================================================
#  archkj-dotfiles — Collector & Publisher
#  Run this ON YOUR MACHINE to:
#    1. Collect all configs, wallpapers, scripts
#    2. Sanitize sensitive data
#    3. Commit and push to GitHub
#  Usage: bash collect.sh
# ============================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()     { echo -e "${MAGENTA}[collect]${NC} $1"; }
ok()      { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
err()     { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${CYAN}══════════════════════════════${NC}\n${CYAN} $1${NC}\n${CYAN}══════════════════════════════${NC}"; }

# ── Pre-flight ───────────────────────────────────────────────
section "Pre-flight Checks"

if [ "$EUID" -eq 0 ]; then
    err "Do not run as root."
    exit 1
fi

if ! command -v git &>/dev/null; then
    err "git not found. Install it: sudo pacman -S git"
    exit 1
fi

ok "Running as $(whoami)"
ok "Dotfiles repo: $DOTFILES_DIR"

cd "$DOTFILES_DIR"

# ── Git init if needed ───────────────────────────────────────
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    log "Initializing git repo..."
    git init
    git branch -M main
    ok "Git initialized"
fi

# ── Check git remote ─────────────────────────────────────────
section "Git Remote Check"

if ! git remote get-url origin &>/dev/null; then
    warn "No git remote set. Setting up..."
    echo -ne "${CYAN}Enter your GitHub repo URL (e.g. https://github.com/SaroshGabriel/archkj-dotfiles.git): ${NC}"
    read -r REMOTE_URL
    git remote add origin "$REMOTE_URL"
    ok "Remote set to $REMOTE_URL"
else
    ok "Remote: $(git remote get-url origin)"
fi

# ── Create folder structure ──────────────────────────────────
section "Preparing Folder Structure"

mkdir -p "$DOTFILES_DIR/configs/hypr"
mkdir -p "$DOTFILES_DIR/configs/waybar"
mkdir -p "$DOTFILES_DIR/configs/rofi"
mkdir -p "$DOTFILES_DIR/configs/kitty"
mkdir -p "$DOTFILES_DIR/configs/hyprlock"
mkdir -p "$DOTFILES_DIR/configs/networkmanager-dmenu"
mkdir -p "$DOTFILES_DIR/wallpapers"
mkdir -p "$DOTFILES_DIR/docs"
mkdir -p "$DOTFILES_DIR/scripts"
ok "Folder structure ready"

# ── Collect Configs ──────────────────────────────────────────
section "Collecting Config Files"

# Hyprland
if [ -d "$HOME_DIR/.config/hypr" ]; then
    cp -r "$HOME_DIR/.config/hypr/"* "$DOTFILES_DIR/configs/hypr/"
    ok "hypr configs collected"
else
    warn "~/.config/hypr not found, skipping"
fi

# Waybar
if [ -d "$HOME_DIR/.config/waybar" ]; then
    cp -r "$HOME_DIR/.config/waybar/"* "$DOTFILES_DIR/configs/waybar/"
    ok "waybar configs collected"
else
    warn "~/.config/waybar not found, skipping"
fi

# Rofi
if [ -d "$HOME_DIR/.config/rofi" ]; then
    cp -r "$HOME_DIR/.config/rofi/"* "$DOTFILES_DIR/configs/rofi/"
    ok "rofi configs collected"
else
    warn "~/.config/rofi not found, skipping"
fi

# Kitty
if [ -d "$HOME_DIR/.config/kitty" ]; then
    cp -r "$HOME_DIR/.config/kitty/"* "$DOTFILES_DIR/configs/kitty/"
    ok "kitty configs collected"
else
    warn "~/.config/kitty not found, skipping"
fi

# Hyprlock
if [ -d "$HOME_DIR/.config/hyprlock" ]; then
    cp -r "$HOME_DIR/.config/hyprlock/"* "$DOTFILES_DIR/configs/hyprlock/"
    ok "hyprlock configs collected"
else
    warn "~/.config/hyprlock not found, skipping"
fi

# NetworkManager dmenu (rofi-driven wifi menu config)
if [ -d "$HOME_DIR/.config/networkmanager-dmenu" ]; then
    cp -r "$HOME_DIR/.config/networkmanager-dmenu/"* "$DOTFILES_DIR/configs/networkmanager-dmenu/"
    ok "networkmanager-dmenu configs collected"
else
    warn "~/.config/networkmanager-dmenu not found, skipping"
fi

# Bashrc
if [ -f "$HOME_DIR/.bashrc" ]; then
    cp "$HOME_DIR/.bashrc" "$DOTFILES_DIR/configs/bashrc"
    ok ".bashrc collected"
else
    warn "~/.bashrc not found, skipping"
fi

# ── Collect Wallpapers ───────────────────────────────────────
section "Collecting Wallpapers"

WALL_SRC="$HOME_DIR/Pictures/Wallpapers"
if [ -d "$WALL_SRC" ]; then
    WALL_COUNT=$(ls "$WALL_SRC" | wc -l)
    log "Copying $WALL_COUNT wallpapers (this may take a moment)..."
    cp -r "$WALL_SRC/"* "$DOTFILES_DIR/wallpapers/"
    ok "$WALL_COUNT wallpapers collected"
else
    warn "~/Pictures/Wallpapers not found, skipping"
fi

# ── Sanitize Sensitive Data ──────────────────────────────────
section "Sanitizing Sensitive Data"

SENSITIVE_PATTERNS=("token" "password" "secret" "api_key" "PAT" "passwd" "credential")

SCAN_DIRS=("$DOTFILES_DIR/configs" "$DOTFILES_DIR/scripts")
FOUND_ISSUES=0

for dir in "${SCAN_DIRS[@]}"; do
    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        MATCHES=$(grep -ril "$pattern" "$dir" 2>/dev/null || true)
        if [ -n "$MATCHES" ]; then
            warn "Possible sensitive data ('$pattern') found in:"
            echo "$MATCHES" | while read -r f; do echo "    $f"; done
            FOUND_ISSUES=1
        fi
    done
done

if [ "$FOUND_ISSUES" -eq 1 ]; then
    echo ""
    warn "Review the files above before pushing to a public repo!"
    echo -ne "${YELLOW}Continue anyway? (y/N): ${NC}"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        err "Aborted. Clean up sensitive data and re-run."
        exit 1
    fi
else
    ok "No sensitive data found"
fi

# ── Generate package lists ───────────────────────────────────
section "Generating Package Lists"

pacman -Qe | awk '{print $1}' > "$DOTFILES_DIR/docs/pacman-packages.txt"
ok "Pacman package list → docs/pacman-packages.txt"

yay -Qm | awk '{print $1}' > "$DOTFILES_DIR/docs/aur-packages.txt"
ok "AUR package list → docs/aur-packages.txt"

# ── Git Commit & Push ────────────────────────────────────────
section "Committing and Pushing"

cd "$DOTFILES_DIR"

git add .

# Check if there are changes to commit
if git diff --cached --quiet; then
    warn "No changes to commit — everything is up to date."
else
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
    git commit -m "chore: update dotfiles [$TIMESTAMP]"
    ok "Committed: chore: update dotfiles [$TIMESTAMP]"

    log "Pushing to GitHub..."
    git push -u origin main
    ok "Pushed to $(git remote get-url origin)"
fi

# ── Done ─────────────────────────────────────────────────────
section "Collection Complete!"

echo -e "${GREEN}All configs, wallpapers, and scripts collected and pushed!${NC}\n"
echo -e "Repo: ${CYAN}$(git remote get-url origin)${NC}"
echo -e "Anyone can now clone and run ${CYAN}bash install.sh${NC} to replicate your system."
echo ""
