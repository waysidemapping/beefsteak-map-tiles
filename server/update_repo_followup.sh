#!/bin/bash

set -x # echo on
set -euo pipefail

# This script (the latest version) is run immediately after the Beefsteak repo has been replaced.
# We must take care of any migration needed between the old files and the new files.

bash /usr/src/app/server/update_postgres_config.sh

bash /usr/src/app/server/update_sql_functions.sh

bash /usr/src/app/server/update_vcl.sh

bash /usr/src/app/server/update_systemd.sh