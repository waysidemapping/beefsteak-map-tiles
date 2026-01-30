#!/bin/bash

set -euo pipefail

BASE_URL="http://127.0.0.1:6081/beefsteak"

VARNISHADM="/usr/local/varnish/bin/varnishadm"
ADMIN_ADDR="127.0.0.1:6082"
SECRET="/usr/local/varnish/etc/secret"
# Check that varnish is running
if ! $VARNISHADM -T "$ADMIN_ADDR" -S "$SECRET" ping >/dev/null 2>&1; then
    echo "Varnish not running or admin interface unavailable, exiting"
    exit 0
fi

max_zoom_level=6
max_zoom_max_x=$((2**max_zoom_level-1))

max_concurrent_jobs=${max_concurrent_jobs:-1}

if ! [[ "$max_concurrent_jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo "max_concurrent_jobs must 1 or greater"
  exit 1
fi

jobs_running=0

echo "Summary of tiles to warm..."
total_tiles=0
for (( z=0; z<=max_zoom_level; z++ )); do
  tiles_per_row=$((2**z))
  max_x=$((tiles_per_row-1))
  total_tiles_for_zoom=$((tiles_per_row**2))
  total_tiles=$((total_tiles+total_tiles_for_zoom))
  echo "Zoom ${z}: $total_tiles_for_zoom tiles ($z/0/0 - $z/$max_x/$max_x)"
done
echo "Total: $total_tiles tiles (0/0/0 - $max_zoom_level/$max_zoom_max_x/$max_zoom_max_x)"
echo "Begin warming..."

script_start_ms=$(date +%s%3N)

for (( z=0; z<=max_zoom_level; z++ )); do
  max=$((2**z))
  for x in $(seq 0 $((max-1))); do
    for y in $(seq 0 $((max-1))); do
      url="$BASE_URL/$z/$x/$y"
      (
        # Use curl to download tile and measure size in bytes and time in seconds
        read tile_size tile_time http_code <<< \
          $(curl -s -L \
          -w "%{size_download} %{time_total} %{http_code}" \
          -o /dev/null \
          "$url")

        if [[ "$http_code" != 2* ]]; then
          echo "Unexpected response for $url (HTTP $http_code)"
          exit 1
        fi

        # convert to milliseconds
        tile_time_ms=$(echo "$tile_time" | awk -F. '{printf "%d", ($1 * 1000) + substr($2"000",1,3)}')

        echo "$z/$x/$y: HTTP ${http_code}, $tile_size bytes, $tile_time_ms ms"
        # write stats to file to aggregate synchronously later
        echo "$url $tile_size $tile_time_ms" >> /tmp/tile_stats.txt
      ) & # run in the background

      jobs_running=$((jobs_running + 1))
      if ((jobs_running >= max_concurrent_jobs)); then
        wait -n   # wait for ANY background job to finish
        jobs_running=$((jobs_running - 1))
      fi

    done
  done
done

# wait for any remaining jobs
wait

script_end_ms=$(date +%s%3N)
script_duration_ms=$((script_end_ms - script_start_ms))

# compile stats
total_size=0
total_time_ms=0
largest_tile_size=0
largest_tile_url=""
slowest_tile_time=0
slowest_tile_url=""
while read url size time_ms; do
  if (( size > largest_tile_size )); then
      largest_tile_size=$size
      largest_tile_url="$url"
  fi
  if (( time_ms > slowest_tile_time )); then
      slowest_tile_time=$time_ms
      slowest_tile_url="$url"
  fi
  total_size=$((total_size + size))
  total_time_ms=$((total_time_ms + time_ms))
done < /tmp/tile_stats.txt

rm /tmp/tile_stats.txt

echo "Warming complete..."
echo "Total size of all warm tiles: $total_size bytes"
echo "Largest tile: $largest_tile_url at $largest_tile_size bytes"
echo "Slowest tile: $slowest_tile_url at $slowest_tile_time ms"
echo "Aggregate download time: $total_time_ms ms"
echo "Total script time: $script_duration_ms ms"
