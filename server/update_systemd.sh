#!/bin/bash

set -x # echo on
set -euo pipefail

# Sync all the units with "beefsteak-" prefix from ./systemd/ to /etc/systemd/system/:
#   - Stop and remove old ones
#   - Add and start new ones
#   - Reload daemon if needed
# This will not run on Docker since systemd is not included.

# Check if systemctl command exists (installed)
if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemd is not installed. Exiting."
    exit 0
fi

# Check if PID 1 is systemd (running)
if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    echo "systemd is not running as PID 1. Exiting."
    exit 0
fi

# Directory of this script
SCRIPT_DIR="$(dirname "$0")"

SRC_DIR="$SCRIPT_DIR/systemd"
DST_DIR=/etc/systemd/system
PREFIX=beefsteak-

changed=0

for src in "$SRC_DIR"/"$PREFIX"*; do
    [[ -f $src ]] || continue

    name=$(basename "$src")
    dst="$DST_DIR/$name"

    if ! cmp -s "$src" "$dst" 2>/dev/null; then
        sudo install -m 644 "$src" "$dst"
        changed=1
    fi
done

for dst in "$DST_DIR"/"$PREFIX"*; do
    [[ -f $dst ]] || continue

    name=$(basename "$dst")
    src="$SRC_DIR/$name"

    if [[ ! -f $src ]]; then
        sudo systemctl disable --now "$name" 2>/dev/null || true
        sudo rm -f "$dst"
        changed=1
    fi
done

if (( changed )); then
    sudo systemctl daemon-reload

    for timer in "$SRC_DIR"/"$PREFIX"*.timer; do
        [[ -f $timer ]] || continue
        sudo systemctl enable --now "$(basename "$timer")"
    done
fi
