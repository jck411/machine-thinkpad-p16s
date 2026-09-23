#!/bin/bash
# Canonical yay entry point: recipes run only through isolated-makepkg.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Yay keeps the first value for repeated options. Reject boundary overrides
# rather than relying on command-line ordering, including a premature --.
for argument in "$@"; do
    case "${argument%%=*}" in
        --makepkg|--makepkgconf|--nomakepkgconf|--builddir|--sudo|--sudoflags|--sudoloop|--save|--)
            echo "Isolation option cannot be overridden: ${argument%%=*}" >&2
            exit 2
            ;;
    esac
done
BUILD_ROOT="$HOME/.cache/machine-aur/builds"
export GNUPGHOME="$HOME/.local/state/machine-update/aur-keys"
mkdir -p "$BUILD_ROOT" "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
for tool in bwrap slirp4netns; do
    command -v "$tool" >/dev/null || { echo "Missing isolation dependency: $tool" >&2; exit 1; }
done
# Set the boundary explicitly; never inherit yay makepkg overrides.
exec yay "$@" --builddir "$BUILD_ROOT" \
    --makepkg "$SCRIPT_DIR/isolated-makepkg.py" --nomakepkgconf \
    --sudo "$SCRIPT_DIR/update-sudo.sh" --sudoflags '' --sudoloop=false
