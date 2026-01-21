#!/bin/bash

set -x # echo on
set -euo pipefail

PERSISTENT_DIR="/var/lib/app"
PG_VERSION="18"
PG_CONF_PATH="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
PG_DATA_DIR="$PERSISTENT_DIR/pg_data"

MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Set tileserving params dynamically based on available memory
SHARED_BUFFERS_MB=$(( MEM_KB * 25 / 100 / 1024 ))   # 25% RAM
MAINTENANCE_MB=$(( MEM_KB * 5 / 100 / 1024 ))       # 5% RAM
AUTOVAC_MB=$(( MEM_KB * 2 / 100 / 1024 ))           # 2% RAM
EFFECTIVE_CACHE_MB=$(( MEM_KB * 75 / 100 / 1024 ))  # 75% RAM

AVAILABLE_BYTES=$(df --output=avail -B1 "$PG_DATA_DIR" | tail -n1)
AVAILABLE_TB=$((AVAILABLE_BYTES / 1024 / 1024 / 1024 / 1024))

MIN_WAL_SIZE_GB=4
MAX_WAL_SIZE_GB=16

declare -A PARAMS=(
    ["shared_buffers"]="${SHARED_BUFFERS_MB}MB"
    ["work_mem"]="256MB"                           
    ["maintenance_work_mem"]="${MAINTENANCE_MB}MB"
    ["autovacuum_work_mem"]="${AUTOVAC_MB}MB"
    ["effective_cache_size"]="${EFFECTIVE_CACHE_MB}MB"
    ["wal_level"]="replica"
    ["synchronous_commit"]="on"
    ["full_page_writes"]="on"
    ["checkpoint_timeout"]="15min"
    ["min_wal_size"]="${MIN_WAL_SIZE_GB}GB"
    ["max_wal_size"]="${MAX_WAL_SIZE_GB}GB"
    ["checkpoint_completion_target"]="0.9"
    ["max_connections"]="100"
    ["max_worker_processes"]="12"
    ["max_parallel_workers"]="6"
    ["max_parallel_workers_per_gather"]="3"
    ["parallel_setup_cost"]="500"
    ["parallel_tuple_cost"]="0.05"
    ["max_wal_senders"]="5"
    ["random_page_cost"]="1.0"
    ["effective_io_concurrency"]="128"
    ["temp_buffers"]="32MB"
    ["autovacuum"]="on"
    ["jit"]="off"
)

CONFIG_UPDATED=0
for key in "${!PARAMS[@]}"; do
    value="${PARAMS[$key]}"
    # Check if value is already as desired
    if grep -Eq "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*${value}\b" "$PG_CONF_PATH"; then
        continue
    fi
    # Remove any existing lines for this parameter (commented or active)
    sudo sed -i "/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]]*=/d" "$PG_CONF_PATH"
    # Append desired parameter
    echo "${key} = ${value}" | sudo tee -a "$PG_CONF_PATH" >/dev/null
    CONFIG_UPDATED=1
done

if [ "$CONFIG_UPDATED" -eq 1 ]; then
    # Restart postgres so our config file changes take effect
    sudo service postgresql restart
    until pg_isready > /dev/null 2>&1; do sleep 1; done
fi