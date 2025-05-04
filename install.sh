#!/bin/bash

set -x # echo on
set -e # Exit if any command fails

PLANET_URL="https://download.geofabrik.de/north-america/us/pennsylvania-latest.osm.pbf"
# "https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf"
SCRATCH_DIR="$(pwd)/scratch"
PLANET_FILE="$SCRATCH_DIR/planet-latest.osm.pbf"
SQL_FUNCTIONS_FILE="functions.sql"
LUA_STYLE_FILE="osm2pgsql_style_config.lua"
MARTIN_CONFIG_FILE="martin_config.yaml"
DB_NAME="osm"
DB_USER="osmuser"
TABLE_PREFIX="planet_osm"

# Create helper directory
if [ ! -d "$SCRATCH_DIR" ]; then
    echo "Directory $SCRATCH_DIR does not exist. Creating it..."
    mkdir -p "$SCRATCH_DIR"
else
    echo "Directory $SCRATCH_DIR exists."
fi

# Create linux user matching PG role: needed for pgsql peer authentication 
if id "$DB_USER" &>/dev/null; then
    echo "User '$DB_USER' already exists."
else
    echo "Creating user '$DB_USER'..."
    sudo useradd -m "$DB_USER"
    echo "User '$DB_USER' created."
fi

# Install wget: needed to fetch planetfile
if command -v wget > /dev/null; then
    echo "wget is already installed."
else
    echo "wget not found, installing..."
    
    # Update package list and install wget
    sudo apt update
    sudo apt install -y wget

    # Verify if wget is installed
    if command -v wget > /dev/null; then
        echo "wget successfully installed."
    else
        echo "Failed to install wget."
        exit 1
    fi
fi

# Install git: needed to clone repos
# if ! command -v git &> /dev/null; then
#     echo "Git is not installed. Installing..."
#     sudo apt update
#     sudo apt install -y git
# else
#     echo "Git is installed."
# fi

# Install PostgreSQL
if command -v psql > /dev/null; then
    echo "PostgreSQL is already installed: $(psql -V)"
else
    echo "PostgreSQL is not installed. Proceeding with installation..."

    sudo apt update

    echo "Installing PostgreSQL and PostGIS from default repositories..."
    sudo apt install -y postgresql postgresql-contrib postgis
fi

# Start PostgreSQL
if pg_isready > /dev/null 2>&1; then
    echo "PostgreSQL is running and responsive."
else
    echo "PostgreSQL is not responding. Attempting to start or restart..."

    # Check if the service is running but unresponsive
    if pgrep -x "postgres" > /dev/null; then
        echo "PostgreSQL process is running but not ready. Restarting..."
        sudo service postgresql restart
    else
        echo "PostgreSQL is not running. Starting..."
        sudo service postgresql start
    fi

    # Give it a moment to initialize
    sleep 3

    # Final check
    if pg_isready > /dev/null 2>&1; then
        echo "PostgreSQL is now running and responsive."
    else
        echo "Failed to start or restart PostgreSQL."
        exit 1
    fi
fi

# Install osm2pgsql
if command -v osm2pgsql >/dev/null 2>&1; then
    echo "osm2pgsql is already installed: $(osm2pgsql --version | head -n 1)"
else
    echo "osm2pgsql is not installed. Installing..."

    sudo apt update

    echo "Installing osm2pgsql..."
    sudo apt install -y osm2pgsql

    echo "osm2pgsql installation complete: $(osm2pgsql --version | head -n 1)"
fi

# Setup database
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
    echo "Database '$DB_NAME' exists."
else
    echo "Creating database '$DB_NAME'..."
    # Check if user exists
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER'" | grep -q 1; then
        echo "User '$DB_USER' exists."
    else
        echo "Creating user '$DB_USER'..."
        sudo -u postgres createuser "$DB_USER"
    fi

    sudo -u postgres createdb --encoding=UTF8 --owner="$DB_USER" "$DB_NAME"
    sudo -u postgres psql "$DB_NAME" --command='CREATE EXTENSION postgis;'
    sudo -u postgres psql "$DB_NAME" --command='CREATE EXTENSION hstore;'

    # Generate COLUMN_NAMES by quoting each line in keys.txt and joining with commas
    COLUMN_NAMES=$(sed 's/.*/"&"/' keys.txt | paste -sd, -)
    # Read the SQL file content into a variable
    SQL_CONTENT=$(<"$SQL_FUNCTIONS_FILE")
    # Replace the placeholder with actual column names
    SQL_CONTENT=${SQL_CONTENT//\{\{COLUMN_NAMES\}\}/$COLUMN_NAMES}

    sudo -u postgres psql "$DB_NAME" -v ON_ERROR_STOP=1 <<< "$SQL_CONTENT"
fi

# Load data into database
TABLES_EXISTING=$(sudo -u postgres psql -d "$DB_NAME" -tAc \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '${TABLE_PREFIX}_%';")
if [[ "$TABLES_EXISTING" -gt 0 ]]; then
    echo "osm2pgsql import detected — $TABLES_EXISTING tables found with prefix '${TABLE_PREFIX}_'."
else
    echo "Downloading the OSM Planet file..."
    if [ ! -f "$PLANET_FILE" ]; then
        wget "$PLANET_URL" -O "$PLANET_FILE"
    else
        echo "Planet file already exists: $PLANET_FILE"
    fi

    echo "Running import..."
    sudo -u "$DB_USER" osm2pgsql -d "$DB_NAME" \
        -U "$DB_USER" \
        --create \
        --slim \
        --multi-geometry \
        --output=flex \
        --prefix="$TABLE_PREFIX" \
        --style="$LUA_STYLE_FILE" \
        "$PLANET_FILE"
fi

# Install build-essential: needed to install Martin
if ! dpkg -s build-essential >/dev/null 2>&1; then
    echo "Installing build-essential..."
    apt update && apt install -y build-essential
else
    echo "build-essential already installed."
fi

# Install rust: needed to install Martin
if ! command -v rustc >/dev/null 2>&1; then
    echo "Rust not found. Installing Rust..."
    export RUSTUP_HOME=/usr/local/rustup
    export CARGO_HOME=/usr/local/cargo
    export PATH=/usr/local/cargo/bin:$PATH
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # add cargo to path in current shell without needing to restart
    . "/usr/local/cargo/env"
    rustc --version
else
    echo "Rust is already installed: $(rustc --version)"
fi

# Install Martin: the tileserver
if ! command -v martin >/dev/null 2>&1; then
    echo "Martin not found. Installing with cargo..."
    cargo install cargo-binstall
    cargo binstall martin
    martin --help
else
    echo "Martin is already installed: $(martin --version)"
fi

# start tileserver
sudo -u "$DB_USER" -- /usr/local/cargo/bin/martin --config "martin_config.yaml"