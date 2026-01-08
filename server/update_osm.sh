#!/bin/bash

set -x # echo on
set -euo pipefail

DB_NAME="osm"
DB_USER="osmuser"

OSM2PGSQL_DIR="/usr/local/osm2pgsql"

echo "Running osm2pgsql-replication update..."
# other osm2pgsql parameters are remembered from the import step
sudo -u "$DB_USER" "$OSM2PGSQL_DIR/bin/osm2pgsql-replication" update \
    -d "$DB_NAME" \
    -U "$DB_USER"