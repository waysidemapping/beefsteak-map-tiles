#!/bin/bash

# set -x # echo on

APP_DIR="/usr/src/app"
SQL_FUNCTIONS_FILE="sql/functions.sql"
DB_NAME="osm"

SQL_CONTENT=$(<"$SQL_FUNCTIONS_FILE")

KEY_LIST=$(grep -v '^$' "$APP_DIR/schema_data/key.txt" | sed "s/.*/'&'/" | paste -sd, -)
SQL_CONTENT=${SQL_CONTENT//\{\{KEY_LIST\}\}/$KEY_LIST}

LOW_ZOOM_LINE_KEY_LIST=$(grep -v '^$' "$APP_DIR/schema_data/low_zoom_line_key.txt" | sed "s/.*/'&'/" | paste -sd, -)
SQL_CONTENT=${SQL_CONTENT//\{\{LOW_ZOOM_LINE_KEY_LIST\}\}/$LOW_ZOOM_LINE_KEY_LIST}

LOW_ZOOM_AREA_KEY_LIST=$(grep -v '^$' "$APP_DIR/schema_data/low_zoom_area_key.txt" | sed "s/.*/'&'/" | paste -sd, -)
SQL_CONTENT=${SQL_CONTENT//\{\{LOW_ZOOM_AREA_KEY_LIST\}\}/$LOW_ZOOM_AREA_KEY_LIST}

RELATION_KEY_LIST=$(grep -v '^$' "$APP_DIR/schema_data/relation_key.txt" | sed "s/.*/'&'/" | paste -sd, -)
SQL_CONTENT=${SQL_CONTENT//\{\{RELATION_KEY_LIST\}\}/$RELATION_KEY_LIST}

KEY_PREFIX_LIKE_STATEMENTS=$(grep -v '^$' "$APP_DIR/schema_data/key_prefix.txt" | awk '{print "OR key LIKE \x27" $0 "%\x27"}' | paste -sd' ' -)
SQL_CONTENT=${SQL_CONTENT//\{\{KEY_PREFIX_LIKE_STATEMENTS\}\}/$KEY_PREFIX_LIKE_STATEMENTS}

RELATION_KEY_PREFIX_LIKE_STATEMENTS=$(grep -v '^$' "$APP_DIR/schema_data/relation_key_prefix.txt" | awk '{print "OR key LIKE \x27" $0 "%\x27"}' | paste -sd' ' -)
SQL_CONTENT=${SQL_CONTENT//\{\{RELATION_KEY_PREFIX_LIKE_STATEMENTS\}\}/$RELATION_KEY_PREFIX_LIKE_STATEMENTS}

FIELD_DEFS="$(grep -v '^$' "$APP_DIR/schema_data/key.txt" | sed 's/.*/"&":"String"/' | paste -sd, -)"
FIELD_DEFS="$FIELD_DEFS,$(grep -v '^$' "$APP_DIR/schema_data/key_prefix.txt" | sed 's/.*/"&\*":"String"/' | paste -sd, -)"
SQL_CONTENT=${SQL_CONTENT//\{\{FIELD_DEFS\}\}/$FIELD_DEFS}

sudo -u postgres psql "$DB_NAME" -v ON_ERROR_STOP=1 -f "sql/function_get_ocean_for_tile.sql"
sudo -u postgres psql "$DB_NAME" -v ON_ERROR_STOP=1 <<< "$SQL_CONTENT"
