#!/bin/bash

# Machine Update — ThinkPad P16s Gen 4
# Pull latest dotfiles, reconcile packages, restart changed services.
# Safe to run frequently (e.g., daily or before work sessions).

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
HOST_PROFILE="thinkpad-p16s-gen4"

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║ Machine Update — ThinkPad P16s Gen 4   ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# =========================================================================
# Step 1: Pull repos
# =========================================================================
pull_repos() {
    echo -e "${BOLD}${CYAN}[1/4] Pulling repos${NC}"

    # Pull this machine repo
    if git -C "$MACHINE_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "  ${BLUE}machine-thinkpad-p16s...${NC}"
        git -C "$MACHINE_DIR" pull --ff-only 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} machine-thinkpad-p16s up to date" || \
            echo -e "  ${YELLOW}⚠${NC} machine-thinkpad-p16s pull failed (local changes?)"
    fi

    # Pull dotfiles
    if [ -d "$DOTFILES_DIR/.git" ]; then
        echo -e "  ${BLUE}dotfiles_hyprland...${NC}"
        git -C "$DOTFILES_DIR" pull --ff-only 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} dotfiles_hyprland up to date" || \
            echo -e "  ${YELLOW}⚠${NC} dotfiles_hyprland pull failed (local changes?)"
    else
        echo -e "  ${RED}✗${NC} dotfiles_hyprland not found — run setup.sh first"
    fi
    echo ""
}

# =========================================================================
# Step 2: Package sync (show only)
# =========================================================================
sync_packages() {
    echo -e "${BOLD}${CYAN}[2/4] Package sync${NC}"

    local pkg_script="$DOTFILES_DIR/packages.sh"
    if [ ! -x "$pkg_script" ]; then
        echo -e "  ${RED}✗ packages.sh not found${NC}"
        return 1
    fi

    # Show status — don't auto-install
    "$pkg_script" status "$HOST_PROFILE"

    # Check if anything is missing
    local declared installed missing
    declared=$("$pkg_script" status "$HOST_PROFILE" 2>/dev/null | grep -c "✗" || true)
    if [ "$declared" -gt 0 ]; then
        echo -e "  ${YELLOW}Run './packages.sh install $HOST_PROFILE' in dotfiles to install missing${NC}"
    fi
    echo ""
}

# =========================================================================
# Step 3: Verify symlinks
# =========================================================================
verify_symlinks() {
    echo -e "${BOLD}${CYAN}[3/4] Config symlinks${NC}"

    local sync_script="$DOTFILES_DIR/sync.sh"
    if [ ! -x "$sync_script" ]; then
        echo -e "  ${RED}✗ sync.sh not found${NC}"
        return 1
    fi

    "$sync_script" status
}

# =========================================================================
# Step 4: Service check
# =========================================================================
check_services() {
    echo -e "${BOLD}${CYAN}[4/4] Systemd services${NC}"

    local services_file="$MACHINE_DIR/system/services.txt"
    if [ ! -f "$services_file" ]; then
        echo -e "  ${YELLOW}⚠ No services.txt — skipping${NC}"
        return 0
    fi

    local all_ok=1
    while IFS= read -r service || [[ -n "$service" ]]; do
        [[ "$service" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${service// }" ]] && continue

        if systemctl is-enabled "$service" &>/dev/null; then
            if systemctl is-active "$service" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $service (enabled, running)"
            else
                echo -e "  ${YELLOW}⚠${NC} $service (enabled, not running)"
                all_ok=0
            fi
        else
            echo -e "  ${RED}✗${NC} $service (not enabled)"
            all_ok=0
        fi
    done < "$services_file"

    if [ "$all_ok" -eq 0 ]; then
        echo ""
        echo -e "  ${YELLOW}Run './setup.sh services' to fix service issues${NC}"
    fi
    echo ""
}

# =========================================================================
# System updates (Arch)
# =========================================================================
system_update() {
    echo -e "${BOLD}${CYAN}=== System Update ===${NC}"
    echo -e "${YELLOW}This will run pacman -Syu and yay -Sua${NC}"
    read -p "Continue? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Updating official repos...${NC}"
        sudo pacman -Syu

        echo -e "${BLUE}Updating AUR packages...${NC}"
        yay -Sua

        echo -e "${GREEN}✓ System updated${NC}"
    else
        echo -e "${YELLOW}Skipped${NC}"
    fi
}

# =========================================================================
# Main
# =========================================================================
show_help() {
    echo "Usage: ./update.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status       Check everything without changing anything (default)"
    echo "  pull         Pull all repos"
    echo "  packages     Show package diff"
    echo "  services     Check service status"
    echo "  system       Run pacman -Syu + yay -Sua"
    echo "  full         Pull + packages + services + system update"
    echo "  help         Show this help"
}

main() {
    print_header

    case "${1:-status}" in
        status)
            pull_repos
            sync_packages
            verify_symlinks
            check_services
            echo -e "${GREEN}${BOLD}✓ Status check complete${NC}"
            ;;
        pull)
            pull_repos
            ;;
        packages)
            sync_packages
            ;;
        services)
            check_services
            ;;
        system)
            system_update
            ;;
        full)
            pull_repos
            sync_packages
            verify_symlinks
            check_services
            system_update
            echo -e "${GREEN}${BOLD}✓ Full update complete${NC}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
