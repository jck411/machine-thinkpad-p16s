#!/bin/bash

# Machine Update — ThinkPad P16s Gen 4
# Inspect package, config, and service state; pull/upgrade only when requested.
# Safe to run frequently (e.g., daily or before work sessions).

set -e


export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -oBatchMode=yes"

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

    local repo
    for repo in "$MACHINE_DIR" "$DOTFILES_DIR"; do
        echo "  $(basename "$repo")..."
        git -C "$repo" pull --ff-only || return 1
    done
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

    "$pkg_script" status "$HOST_PROFILE"
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

    local scope file service properties key value enabled active result type state
    local issues=0
    local -a ctl
    for scope in system user; do
        ctl=(systemctl)
        file="$MACHINE_DIR/system/services.txt"
        if [ "$scope" = user ]; then
            ctl+=(--user)
            file="$MACHINE_DIR/system/user-services.txt"
        fi
        if [ ! -f "$file" ]; then
            echo "  Missing service list: $file"
            issues=1
            continue
        fi
        while IFS= read -r service || [[ -n "$service" ]]; do
            [[ "$service" =~ ^[[:space:]]*# || -z "${service// }" ]] && continue
            enabled= active= result= type= state=
            if ! properties=$("${ctl[@]}" show "$service" -p UnitFileState -p ActiveState -p Result -p Type -p SubState); then
                echo "  ✗ $service ($scope, unable to query)"
                issues=1
                continue
            fi
            while IFS='=' read -r key value; do
                case "$key" in
                    UnitFileState) enabled="$value" ;;
                    ActiveState) active="$value" ;;
                    Result) result="$value" ;;
                    Type) type="$value" ;;
                    SubState) state="$value" ;;
                esac
            done <<< "$properties"
            if [[ "$active" = failed || ( -n "$result" && "$result" != success ) ]]; then
                echo "  ✗ $service ($scope, $active/$state, result=$result)"
                issues=1
            elif [[ "$enabled" != enabled && "$enabled" != enabled-runtime ]]; then
                echo "  ✗ $service ($scope, ${enabled:-not installed}, $active/$state)"
                issues=1
            elif [[ "$active" = active ]]; then
                echo "  ✓ $service ($scope, $enabled, $active/$state)"
            elif [[ "$active" = inactive && ( "$type" = oneshot || "$service" = NetworkManager-dispatcher.service ) ]]; then
                echo "  ✓ $service ($scope, $enabled, inactive; boot/on-demand unit, no recorded failure)"
            else
                echo "  ⚠ $service ($scope, $enabled, $active/$state)"
                issues=1
            fi
        done < "$file"
    done
    if [ "$issues" -ne 0 ]; then
        echo "Inspect flagged units with systemctl [--user] status UNIT and journalctl."
        echo "setup.sh services enables declared units; it does not repair runtime failures."
    fi
    echo ""
    return "$issues"
}

check_status() {
    local issues=0
    sync_packages || issues=1
    verify_symlinks || issues=1
    check_services || issues=1
    if [ "$issues" -ne 0 ]; then
        echo "⚠ Status check found issues; review the findings above."
        return 1
    fi
    echo "✓ Status checks passed; undeclared packages and unmanaged configs are informational."
}

# =========================================================================
# System updates (Arch)
# =========================================================================
system_update() {
    "$MACHINE_DIR/scripts/system-update.sh"
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
    echo "  system       Update official + AUR packages without prompts"
    echo "  full         Pull + packages + services + system update"
    echo "  help         Show this help"
}

main() {
    print_header

    case "${1:-status}" in
        status)
            echo "[1/4] Local repository status (no fetch or pull)"
            git -C "$MACHINE_DIR" status --short --branch
            git -C "$DOTFILES_DIR" status --short --branch
            check_status
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
            system_update
            check_status
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
