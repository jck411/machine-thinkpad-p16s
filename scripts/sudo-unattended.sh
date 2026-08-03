#!/bin/bash

# Supply the stored machine password to one sudo invocation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/../secrets/.env"

if [ ! -r "$SECRETS_FILE" ]; then
    echo "Error: secrets file is not readable: $SECRETS_FILE" >&2
    exit 1
fi

set +u
source "$SECRETS_FILE"
set -u

if [ -z "${SUDO_PASSWORD:-}" ]; then
    echo "Error: SUDO_PASSWORD is missing from $SECRETS_FILE" >&2
    exit 1
fi

printf '%s\n' "$SUDO_PASSWORD" | /usr/bin/sudo -S -p '' "$@"
