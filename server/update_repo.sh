#!/bin/bash

set -x # echo on
set -euo pipefail

REPO_DIR="/usr/src/app"

cd "$REPO_DIR"

echo "Checking for upstream updates to repo at $REPO_DIR..."

git fetch origin
if [ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]; then
    echo "Repo is behind upstream. Pulling changes..."
    
    if git pull --ff-only; then
        echo "Pull successful. Running followup script..."
        # Run any followup specified by the newly downloaded script, if found and executable
        if [[ -x "$REPO_DIR/server/update_repo_followup.sh" ]]; then
            bash "$REPO_DIR/server/update_repo_followup.sh"
        else
            echo "Could not run followup script"
        fi
    else
        exit 1
    fi
else
    echo "Repo is already up-to-date"
fi
