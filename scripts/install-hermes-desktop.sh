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

patch_file="$MACHINE_DIR/system/hermes/remote-restart.patch"
# An upstream update can replace main.ts while retaining patch-created files.
stats=$(git -C "$HERMES_ROOT" apply --numstat "$patch_file")
pending=()
while IFS=$'\t' read -r added removed path; do
    if git -C "$HERMES_ROOT" apply --reverse --check "--include=$path" "$patch_file" 2>/dev/null; then
        continue
    fi
    git -C "$HERMES_ROOT" apply --check "--include=$path" "$patch_file"
    pending+=("--include=$path")
done <<< "$stats"
if ((${#pending[@]})); then
    git -C "$HERMES_ROOT" apply "${pending[@]}" "$patch_file"
fi
# Hermes's content stamp rebuilds only when installed sources have changed.
"$HERMES_COMMAND" desktop --build-only
