#!/bin/bash
# Install the official Hermes runtime and desktop client for the home gateway.
set -euo pipefail

MACHINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HERMES_HOME="$HOME/.hermes"
HERMES_ROOT="$HERMES_HOME/hermes-agent"
HERMES_COMMAND="$HOME/.local/bin/hermes"
CONNECTION_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/Hermes/connection.json"

if [ ! -x "$HERMES_COMMAND" ]; then
    installer=$(mktemp)
    trap 'rm -f "$installer"' EXIT
    curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh" -o "$installer"
    bash "$installer" --branch main \
        --skip-setup --skip-browser --skip-computer-use --non-interactive
fi

# Settings and login state remain app-owned, outside the dotfiles repository.
"$HERMES_COMMAND" config set desktop.ozone_platform_hint wayland
"$HERMES_COMMAND" config set desktop.electron_flags '["--ozone-platform=wayland", "--enable-wayland-ime"]'

if [ ! -e "$CONNECTION_FILE" ]; then
    gateway_url=$(jq -er '.[] | select(.name == "Hermes") | .public_url' \
        "$MACHINE_DIR/../NETWORK/lxc/services.json")
    mkdir -p "$(dirname "$CONNECTION_FILE")"
    (umask 077; jq -n --arg url "$gateway_url" \
        '{mode: "remote", remote: {url: $url, authMode: "oauth"}, profiles: {}}' \
        > "$CONNECTION_FILE")
fi

if [ -x "$HERMES_ROOT/apps/desktop/release/linux-unpacked/Hermes" ]; then
    "$HERMES_COMMAND" desktop --skip-build --build-only
else
    "$HERMES_COMMAND" desktop --build-only
fi
