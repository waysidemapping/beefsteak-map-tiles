#!/bin/bash

# set -x # echo on
set -e # Exit if any command fails

APP_DIR="/usr/src/app"
SQL_FUNCTIONS_FILE="functions.sql"
DB_NAME="osm"

# Use the latest lists instead of the lists at import since all tags are present in the db, we're just filtering 
JSONB_KEYS=$(grep -v '^$' "$APP_DIR/helper_data/output_keys.txt" | sed "s/.*/'&'/" | paste -sd, -)
JSONB_PREFIXES=$(grep -v '^$' "$APP_DIR/helper_data/output_key_prefixes.txt" | awk '{print "OR key LIKE \x27" $0 "%\x27"}' | paste -sd' ' -)

FIELD_DEFS="$(grep -v '^$' "$APP_DIR/helper_data/output_keys.txt" | sed 's/.*/"&":"String"/' | paste -sd, -)"
FIELD_DEFS="$FIELD_DEFS,$(grep -v '^$' "$APP_DIR/helper_data/output_key_prefixes.txt" | sed 's/.*/"&\*":"String"/' | paste -sd, -)"

SQL_CONTENT=$(<"$SQL_FUNCTIONS_FILE")
SQL_CONTENT=${SQL_CONTENT//\{\{JSONB_KEYS\}\}/$JSONB_KEYS}
SQL_CONTENT=${SQL_CONTENT//\{\{JSONB_PREFIXES\}\}/$JSONB_PREFIXES}
SQL_CONTENT=${SQL_CONTENT//\{\{FIELD_DEFS\}\}/$FIELD_DEFS}

sudo -u postgres psql "$DB_NAME" -v ON_ERROR_STOP=1 <<< "$SQL_CONTENT"
