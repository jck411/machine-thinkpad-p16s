#!/bin/bash

# Authenticate each yay sudo invocation without sharing secrets with builds.
set +x
set -euo pipefail
set +a
unset SUDO_PASSWORD PASSWORD

MACHINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$MACHINE_DIR/secrets/.env"
if [ ! -f "$ENV_FILE" ] || [ ! -O "$ENV_FILE" ] ||
    [ "$(stat -c '%a' "$ENV_FILE")" != 600 ]; then
    echo "Error: secrets/.env must exist, be owned by this user, and have mode 600." >&2
    exit 1
fi

# Source only in a subshell: other machine credentials never reach sudo or yay.
PASSWORD="$(
    source "$ENV_FILE" >/dev/null 2>&1
    printf '%s' "${SUDO_PASSWORD:-}"
)"
if [ -z "$PASSWORD" ]; then
    echo "Error: SUDO_PASSWORD is missing from secrets/.env." >&2
    exit 1
fi

# A bad password gets EOF rather than another interactive attempt.
printf '%s\n' "$PASSWORD" | /usr/bin/sudo -S -p '' "$@"
