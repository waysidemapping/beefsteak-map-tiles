#!/bin/bash

set -x # echo on
set -euo pipefail

# Directory of this script
SCRIPT_DIR="$(dirname "$0")"

VARNISHADM="/usr/local/varnish/bin/varnishadm"
ADMIN_ADDR="127.0.0.1:6082"
SECRET="/usr/local/varnish/etc/secret"

DESIRED_VCL="$SCRIPT_DIR/config/varnish_config.vcl"
ACTIVE_VCL_COPY="/var/lib/app/active_varnish_config.vcl"

echo "Attempting live VCL update if needed"

# Check that varnish is running
if ! $VARNISHADM -T "$ADMIN_ADDR" -S "$SECRET" ping >/dev/null 2>&1; then
    echo "Varnish not running or admin interface unavailable, exiting"
    exit 0
fi

# Check that new file exists
if [[ ! -f "$DESIRED_VCL" ]]; then
    echo "VCL file not found: $DESIRED_VCL"
    exit 1
fi

new_hash=$(sha256sum "$DESIRED_VCL" | awk '{print $1}')
old_hash=""

if [[ -f "$ACTIVE_VCL_COPY" ]]; then
    old_hash=$(sha256sum "$ACTIVE_VCL_COPY" | awk '{print $1}')
fi

# It's okay if we accidentally reload the same config, just not preferable
if [[ "$new_hash" == "$old_hash" ]]; then
    echo "VCL unchanged, skipping reload"
    exit 0
fi

# Config is different, run update...

# Generate a unique name from the current timestamp
DESIRED_VCL_NAME="vcl_$(date +%s)"

# Save the name of the active config
ACTIVE_VCL=$(
    $VARNISHADM -T "$ADMIN_ADDR" -S "$SECRET" vcl.list |
    awk '$1 == "active" {print $3}'
)

# Sense check
if [[ -z "$ACTIVE_VCL" || "$ACTIVE_VCL" == "$DESIRED_VCL_NAME" ]]; then
    echo "Found issue with active VCL: $ACTIVE_VCL"
    exit 1
fi

# Add the new config
$VARNISHADM -T "$ADMIN_ADDR" -S "$SECRET" \
    vcl.load "$DESIRED_VCL_NAME" "$DESIRED_VCL"

# Live swap to the new config
$VARNISHADM -T "$ADMIN_ADDR" -S "$SECRET" \
    vcl.use "$DESIRED_VCL_NAME"

# Delete the old config
$VARNISHADM -T "$ADMIN_ADDR" -S "$SECRET" \
    vcl.discard "$ACTIVE_VCL"

# Cache our new config where we can reference it later
cp "$DESIRED_VCL" "$ACTIVE_VCL_COPY"

echo "VCL update complete"
