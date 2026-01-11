#!/bin/bash

set -x # echo on
set -euo pipefail

# Directory of this current script
SCRIPT_DIR="$(dirname "$0")"

DB_NAME="osm"

echo "Running post-import SQL queries..."
psql "$DB_NAME" \
    --file="$SCRIPT_DIR/sql/post_init_or_update/area_relation.sql"