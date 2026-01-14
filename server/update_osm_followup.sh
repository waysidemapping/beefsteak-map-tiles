#!/bin/bash

set -x # echo on
set -euo pipefail

# Directory of this current script
SCRIPT_DIR="$(dirname "$0")"

DB_NAME="osm"

start=$(date +%s)
echo "$(date '+%Y-%m-%d %H:%M:%S'): Running post-import SQL queries..."
psql "$DB_NAME" \
    --file="$SCRIPT_DIR/sql/post_init_or_update/area_relation.sql"
end=$(date +%s)
duration=$((end - start))
echo "$(date '+%Y-%m-%d %H:%M:%S'): Completed post-import SQL queries in $duration s"

# script runs its own echos
python3 "$SCRIPT_DIR/process_expired_tiles.py"