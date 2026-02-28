#!/bin/bash

# Post-Install Bootstrap — ThinkPad P16s Gen 4
# Run this ONCE after a fresh EndeavourOS install.
# It clones repos, runs setup, and verifies everything.
#
# Usage: curl the raw URL or copy this to the new machine and run:
#   chmod +x bootstrap.sh && ./bootstrap.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

REPOS_DIR="$HOME/REPOS"
DOTFILES_REPO="https://github.com/jck411/dotfiles_hyprland.git"
MACHINE_REPO="https://github.com/jck411/machine-thinkpad-p16s.git"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║  Bootstrap — ThinkPad P16s Gen 4           ║"
echo "║  EndeavourOS Post-Install                  ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# =========================================================================
# Step 0: Verify we're on Arch
# =========================================================================
if ! command -v pacman &>/dev/null; then
    echo -e "${RED}✗ This script is for Arch-based systems (pacman not found)${NC}"
    exit 1
fi

# =========================================================================
# Step 1: System update + essential tools
# =========================================================================
echo -e "${BOLD}${CYAN}[1/6] System update + essentials${NC}"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel

# Ensure yay is available (EndeavourOS includes it)
if ! command -v yay &>/dev/null; then
    echo -e "  ${BLUE}Installing yay...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ~
fi
echo -e "  ${GREEN}✓${NC} System updated, git + yay available"
echo ""

# =========================================================================
# Step 2: Git config
# =========================================================================
echo -e "${BOLD}${CYAN}[2/6] Git config${NC}"
if ! git config --global user.name &>/dev/null; then
    git config --global user.name "jack"
    git config --global user.email "jck411@gmail.com"
    echo -e "  ${GREEN}✓${NC} Git identity set"
else
    echo -e "  ${GREEN}✓${NC} Git identity already configured"
fi
git config --global init.defaultBranch main
echo ""

# =========================================================================
# Step 3: Clone repos
# =========================================================================
echo -e "${BOLD}${CYAN}[3/6] Cloning repos${NC}"
mkdir -p "$REPOS_DIR"

if [ -d "$REPOS_DIR/dotfiles_hyprland/.git" ]; then
    echo -e "  ${GREEN}✓${NC} dotfiles_hyprland already cloned"
    git -C "$REPOS_DIR/dotfiles_hyprland" pull --ff-only || true
else
    echo -e "  ${BLUE}Cloning dotfiles_hyprland...${NC}"
    git clone "$DOTFILES_REPO" "$REPOS_DIR/dotfiles_hyprland"
fi

if [ -d "$REPOS_DIR/machine-thinkpad-p16s/.git" ]; then
    echo -e "  ${GREEN}✓${NC} machine-thinkpad-p16s already cloned"
    git -C "$REPOS_DIR/machine-thinkpad-p16s" pull --ff-only || true
else
    echo -e "  ${BLUE}Cloning machine-thinkpad-p16s...${NC}"
    git clone "$MACHINE_REPO" "$REPOS_DIR/machine-thinkpad-p16s"
fi
echo ""

# =========================================================================
# Step 4: Switch repos to SSH remotes (for push access)
# =========================================================================
echo -e "${BOLD}${CYAN}[4/6] Configure SSH remotes${NC}"
echo -e "  ${YELLOW}⚠ After setting up SSH keys, switch remotes to SSH:${NC}"
echo -e "  ${YELLOW}  cd ~/REPOS/dotfiles_hyprland && git remote set-url origin git@github.com:jck411/dotfiles_hyprland.git${NC}"
echo -e "  ${YELLOW}  cd ~/REPOS/machine-thinkpad-p16s && git remote set-url origin git@github.com:jck411/machine-thinkpad-p16s.git${NC}"
echo ""

# =========================================================================
# Step 5: Run machine setup
# =========================================================================
echo -e "${BOLD}${CYAN}[5/6] Running machine setup${NC}"
"$REPOS_DIR/machine-thinkpad-p16s/setup.sh"
echo ""

# =========================================================================
# Step 6: Verify
# =========================================================================
echo -e "${BOLD}${CYAN}[6/6] Verification${NC}"

# GPU
echo -e "  ${BLUE}GPU:${NC}"
if command -v glxinfo &>/dev/null; then
    glxinfo 2>/dev/null | grep "OpenGL renderer" | sed 's/^/    /'
else
    lspci 2>/dev/null | grep -i vga | sed 's/^/    /'
fi

# CPU governor
echo -e "  ${BLUE}CPU scaling driver:${NC}"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null | sed 's/^/    /' || echo "    (not available yet — reboot first)"

# Wi-Fi
echo -e "  ${BLUE}Wi-Fi:${NC}"
ip link 2>/dev/null | grep -E "wl[a-z]" | sed 's/^/    /' || echo "    (no wireless interface found)"

# Services
echo -e "  ${BLUE}Key services:${NC}"
for svc in sddm NetworkManager bluetooth pcscd fstrim.timer earlyoom power-profiles-daemon; do
    if systemctl is-enabled "$svc" &>/dev/null; then
        echo -e "    ${GREEN}✓${NC} $svc"
    else
        echo -e "    ${YELLOW}⚠${NC} $svc (not enabled)"
    fi
done

echo ""
echo -e "${GREEN}${BOLD}✓ Bootstrap complete!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Reboot into SDDM"
echo -e "  2. Log in — Hyprland should appear as a session option"
echo -e "  3. Set up SSH keys for GitHub push access"
echo -e "  4. Run: ${BOLD}vainfo${NC} to verify hardware video decode"
echo -e "  5. Run: ${BOLD}./update.sh${NC} in machine-thinkpad-p16s to verify everything"
