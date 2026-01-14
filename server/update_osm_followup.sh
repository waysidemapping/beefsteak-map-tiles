#!/bin/bash

set -x # echo on
set -euo pipefail

# Directory of this current script
SCRIPT_DIR="$(dirname "$0")"

DB_NAME="osm"

start=$(date +%s)
echo "Start: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Running post-import SQL queries..."
psql "$DB_NAME" \
    --file="$SCRIPT_DIR/sql/post_init_or_update/area_relation.sql"
echo "Done running post-import SQL queries"
end=$(date +%s)
echo "End:   $(date '+%Y-%m-%d %H:%M:%S')"
duration=$((end - start))
echo "Duration: $duration seconds"

# script runs its own echos
python3 "$SCRIPT_DIR/process_expired_tiles.py"