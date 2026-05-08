#!/bin/bash
set -e

# Creates symlinks in every repo pointing to ~/ENV/.env
# Run this once on a new machine after populating ~/ENV/.env

MASTER="$HOME/REPOS/symlinked-env/.env"
REPOS="$HOME/REPOS"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ ! -f "$MASTER" ]]; then
    echo -e "${RED}ERROR: $MASTER not found.${NC}"
    echo "Copy ~/REPOS/symlinked-env/.env.example to ~/REPOS/symlinked-env/.env and fill in your secrets first."
    exit 1
fi

# Repos that need a .env symlink at their root
TARGETS=(
    "$REPOS/Backend_FastAPI"
    "$REPOS/mcp-servers"
    "$REPOS/PROXMOX"
    "$REPOS/Immich"
    "$REPOS/librechat-config"
    "$REPOS/jackshome.com"
    "$REPOS/opencode-config"
    "$REPOS/knowledge_chat"
    "$REPOS/Knowledge"
    "$REPOS/calendar"
    "$REPOS/Trading"
    "$REPOS/NETWORK"
)

# machine-thinkpad-p16s uses secrets/.env
SECRETS_DIR="$REPOS/machine-thinkpad-p16s/secrets"

for dir in "${TARGETS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo -e "${YELLOW}SKIP${NC}  $dir (directory not found)"
        continue
    fi
    target="$dir/.env"
    if [[ -L "$target" && "$(readlink "$target")" == "$MASTER" ]]; then
        echo -e "${GREEN}OK${NC}     $target"
    else
        ln -sf "$MASTER" "$target"
        echo -e "${GREEN}LINKED${NC} $target"
    fi
done

# Handle machine-thinkpad-p16s separately (secrets/.env)
mkdir -p "$SECRETS_DIR"
target="$SECRETS_DIR/.env"
if [[ -L "$target" && "$(readlink "$target")" == "$MASTER" ]]; then
    echo -e "${GREEN}OK${NC}     $target"
else
    ln -sf "$MASTER" "$target"
    echo -e "${GREEN}LINKED${NC} $target"
fi

echo ""
    echo -e "${GREEN}Done.${NC} All repos symlinked to $MASTER"
