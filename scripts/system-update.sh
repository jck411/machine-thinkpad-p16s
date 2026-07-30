#!/bin/bash

# Canonical unattended Arch + AUR update for this machine.

set -Eeuo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/machine-update"
STATUS_FILE="$STATE_DIR/status"
SUCCESS_FILE="$STATE_DIR/last-success"
LOG_FILE="$STATE_DIR/update.log"
LOCK_FILE="$STATE_DIR/update.lock"
SUDO_WRAPPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sudo-unattended.sh"
STARTED_AT="$(date --iso-8601=seconds)"
POSTFLIGHT_WARNINGS=0

mkdir -p "$STATE_DIR"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Error: another system update is already running." >&2
    exit 1
fi

exec > >(tee -a "$LOG_FILE") 2>&1

write_status() {
    local state="$1"
    local detail="${2:-}"
    local temporary="$STATUS_FILE.$$"

    {
        printf 'state=%s\n' "$state"
        printf 'started_at=%s\n' "$STARTED_AT"
        printf 'updated_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'pid=%s\n' "$$"
        printf 'log=%s\n' "$LOG_FILE"
        if [ -n "$detail" ]; then
            printf '%s\n' "$detail"
        fi
    } > "$temporary"
    mv "$temporary" "$STATUS_FILE"
}

fail_update() {
    local exit_code=$?

    trap - ERR
    write_status "failed" "exit_code=$exit_code"
    echo
    echo "Update failed (exit $exit_code). See: $LOG_FILE" >&2
    exit "$exit_code"
}

stop_update() {
    local signal="$1"
    local exit_code="$2"

    trap - INT TERM
    write_status "failed" "signal=$signal"
    echo
    echo "Update interrupted by $signal. See: $LOG_FILE" >&2
    exit "$exit_code"
}

authenticate_sudo() {
    if "$SUDO_WRAPPER" -v; then
        return 0
    fi

    echo "Error: stored SUDO_PASSWORD was rejected." >&2
    echo "Update $HOME/REPOS/symlinked-env/.env and rerun." >&2
    return 1
}

report_postflight() {
    local findings

    echo
    echo "Post-update checks"

    findings="$(pacdiff -o 2>/dev/null || true)"
    if [ -n "$findings" ]; then
        echo "WARNING: configuration merges are waiting:"
        printf '%s\n' "$findings"
        POSTFLIGHT_WARNINGS=$((POSTFLIGHT_WARNINGS + 1))
    else
        echo "✓ No pending .pacnew files"
    fi

    if command -v checkrebuild >/dev/null 2>&1; then
        findings="$(checkrebuild -v 2>&1 || true)"
        if [ -n "$findings" ]; then
            echo "WARNING: packages with stale or missing library links:"
            printf '%s\n' "$findings"
            POSTFLIGHT_WARNINGS=$((POSTFLIGHT_WARNINGS + 1))
        else
            echo "✓ No packages need rebuilding"
        fi
    fi

    findings="$(pacman -Qdtq 2>/dev/null || true)"
    if [ -n "$findings" ]; then
        echo "WARNING: orphaned packages remain (not removed automatically):"
        printf '%s\n' "$findings"
        POSTFLIGHT_WARNINGS=$((POSTFLIGHT_WARNINGS + 1))
    else
        echo "✓ No orphaned packages"
    fi

    findings="$(systemctl --failed --no-legend --plain 2>/dev/null || true)"
    if [ -n "$findings" ]; then
        echo "WARNING: failed system services:"
        printf '%s\n' "$findings"
        POSTFLIGHT_WARNINGS=$((POSTFLIGHT_WARNINGS + 1))
    else
        echo "✓ No failed system services"
    fi

}

trap fail_update ERR
trap 'stop_update INT 130' INT
trap 'stop_update TERM 143' TERM

write_status "running"

echo
echo "System update started: $STARTED_AT"
echo "Log: $LOG_FILE"

authenticate_sudo

echo
echo "Updating official and AUR packages noninteractively..."
yay --sudo "$SUDO_WRAPPER" -Syu --noconfirm

report_postflight
FINISHED_AT="$(date --iso-8601=seconds)"
SUCCESS_EPOCH="$(date +%s)"
SUCCESS_TEMPORARY="$SUCCESS_FILE.$$"

printf '%s\n' "$SUCCESS_EPOCH" > "$SUCCESS_TEMPORARY"
mv "$SUCCESS_TEMPORARY" "$SUCCESS_FILE"
write_status "success" "warnings=$POSTFLIGHT_WARNINGS"

echo
echo "✓ System update completed: $FINISHED_AT"
if [ "$POSTFLIGHT_WARNINGS" -gt 0 ]; then
    echo "Completed with $POSTFLIGHT_WARNINGS post-update warning(s); review the log above."
fi
