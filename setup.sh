#!/bin/bash

# Machine Setup — ThinkPad P16s Gen 4
# Idempotent bootstrap: clone dotfiles, install packages, link configs, enable services.
# Safe to re-run at any time.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

MACHINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(dirname "$MACHINE_DIR")"
DOTFILES_DIR="$REPOS_DIR/dotfiles_hyprland"
DOTFILES_REPO="git@github.com:jck411/dotfiles_hyprland.git"
HOST_PROFILE="thinkpad-p16s-gen4"

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║  Machine Setup — ThinkPad P16s Gen 4   ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# =========================================================================
# Step 1: Ensure dotfiles repo exists
# =========================================================================
setup_dotfiles() {
    echo -e "${BOLD}${CYAN}[1/4] Dotfiles repo${NC}"

    if [ -d "$DOTFILES_DIR/.git" ]; then
        echo -e "  ${GREEN}✓${NC} Already cloned at $DOTFILES_DIR"
        echo -e "  ${BLUE}Pulling latest...${NC}"
        git -C "$DOTFILES_DIR" pull --ff-only || {
            echo -e "  ${YELLOW}⚠ Pull failed (dirty tree?). Skipping pull.${NC}"
        }
    else
        echo -e "  ${BLUE}Cloning dotfiles...${NC}"
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
    echo ""
}

# =========================================================================
# Step 2: Install packages
# =========================================================================
setup_packages() {
    echo -e "${BOLD}${CYAN}[2/4] Packages${NC}"

    local pkg_script="$DOTFILES_DIR/packages.sh"
    if [ ! -x "$pkg_script" ]; then
        echo -e "  ${RED}✗ packages.sh not found or not executable${NC}"
        return 1
    fi

    echo -e "  ${BLUE}Running package sync for host: $HOST_PROFILE${NC}"
    "$pkg_script" install "$HOST_PROFILE"
    echo ""
}

# =========================================================================
# Step 3: Link configs
# =========================================================================
setup_configs() {
    echo -e "${BOLD}${CYAN}[3/4] Config symlinks${NC}"

    local install_script="$DOTFILES_DIR/install.sh"
    if [ ! -x "$install_script" ]; then
        echo -e "  ${RED}✗ install.sh not found or not executable${NC}"
        return 1
    fi

    # Set host profile non-interactively
    local host_link="$DOTFILES_DIR/config/hypr/host.conf"
    ln -sf "hosts/${HOST_PROFILE}.conf" "$host_link"
    echo -e "  ${GREEN}✓${NC} Host profile set to ${BOLD}$HOST_PROFILE${NC}"

    # Run full install (creates all symlinks)
    echo -e "  ${BLUE}Linking configs...${NC}"

    # Install each component non-interactively
    for component in hypr waybar foot foot-quake rofi mako gtk-3.0 gtk-4.0 \
                     Thunar imv mpv networkmanager-dmenu nwg-displays \
                     xdg-desktop-portal scripts; do
        "$install_script" "$component" 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} $component" || \
            echo -e "  ${YELLOW}⚠${NC} $component (may already be linked)"
    done

    for file in brave-flags.conf code-flags.conf cursor-flags.conf \
                electron-flags.conf power-settings.conf; do
        "$install_script" "$file" 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} $file" || \
            echo -e "  ${YELLOW}⚠${NC} $file (may already be linked)"
    done

    "$install_script" shell 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} shell configs" || \
        echo -e "  ${YELLOW}⚠${NC} shell configs (may already be linked)"

    echo ""
}

# =========================================================================
# Step 4: Enable systemd services
# =========================================================================
setup_services() {
    echo -e "${BOLD}${CYAN}[4/4] Systemd services${NC}"

    local services_file="$MACHINE_DIR/system/services.txt"
    if [ ! -f "$services_file" ]; then
        echo -e "  ${YELLOW}⚠ No services.txt found — skipping${NC}"
        return 0
    fi

    local changed=0
    while IFS= read -r service || [[ -n "$service" ]]; do
        # Skip comments and blank lines
        [[ "$service" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${service// }" ]] && continue

        if systemctl is-enabled "$service" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $service (already enabled)"
        else
            echo -e "  ${BLUE}→${NC} Enabling $service..."
            sudo systemctl enable "$service"
            changed=1
        fi
    done < "$services_file"

    # Apply sysctl overrides if present
    local sysctl_file="$MACHINE_DIR/system/sysctl.conf"
    if [ -f "$sysctl_file" ]; then
        echo -e "  ${BLUE}Applying sysctl overrides...${NC}"
        sudo cp "$sysctl_file" /etc/sysctl.d/99-machine.conf
        sudo sysctl --system &>/dev/null
        echo -e "  ${GREEN}✓${NC} sysctl overrides applied"
    fi

    # Deploy NetworkManager configs
    local nm_dir="$MACHINE_DIR/system/networkmanager"
    if [ -d "$nm_dir" ] && [ "$(ls -A "$nm_dir" 2>/dev/null)" ]; then
        echo -e "  ${BLUE}Deploying NetworkManager configs...${NC}"
        sudo mkdir -p /etc/NetworkManager/conf.d
        for conf in "$nm_dir"/*.conf; do
            [ -f "$conf" ] || continue
            local conf_name
            conf_name=$(basename "$conf")
            sudo cp "$conf" "/etc/NetworkManager/conf.d/$conf_name"
            echo -e "  ${GREEN}✓${NC} $conf_name"
        done
        sudo nmcli general reload 2>/dev/null || true
    fi

    # Copy custom systemd units if present
    local units_dir="$MACHINE_DIR/system/systemd"
    if [ -d "$units_dir" ] && [ "$(ls -A "$units_dir" 2>/dev/null)" ]; then
        echo -e "  ${BLUE}Installing custom systemd units...${NC}"
        for unit in "$units_dir"/*; do
            local unit_name
            unit_name=$(basename "$unit")
            sudo cp "$unit" "/etc/systemd/system/$unit_name"
            echo -e "  ${GREEN}✓${NC} Installed $unit_name"
        done
        sudo systemctl daemon-reload
    fi

    echo ""
}

# =========================================================================
# Main
# =========================================================================
main() {
    print_header

    case "${1:-all}" in
        all)
            setup_dotfiles
            setup_packages
            setup_configs
            setup_services
            echo -e "${GREEN}${BOLD}✓ Setup complete!${NC}"
            ;;
        dotfiles)
            setup_dotfiles
            ;;
        packages)
            setup_packages
            ;;
        configs)
            setup_configs
            ;;
        services)
            setup_services
            ;;
        help|--help|-h)
            echo "Usage: ./setup.sh [STEP]"
            echo ""
            echo "Steps:"
            echo "  all        Run all steps (default)"
            echo "  dotfiles   Clone/pull dotfiles repo"
            echo "  packages   Install declared packages"
            echo "  configs    Link config files"
            echo "  services   Enable systemd services"
            ;;
        *)
            echo -e "${RED}Unknown step: $1${NC}"
            exit 1
            ;;
    esac
}

main "$@"
