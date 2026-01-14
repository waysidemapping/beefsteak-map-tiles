#!/bin/bash

# set -x # echo on
set -euo pipefail

VARNISHADM="/usr/local/varnish/bin/varnishadm"
ADMIN_ADDR="127.0.0.1:6082"
SECRET="/usr/local/varnish/etc/secret"

# This is the file set in the defined_expire_output parameter in the osm2pgsl lua style.
# It's expected to have lines of text corresponding to tiles that need re-rendering in the format Z/X/Y
EXPIRE_FILE="/var/lib/app/expired_tiles.txt"
# Prefix for the URL endpoint 
PREFIX="/beefsteak"

# Cap the max length of the ban regex string to avoid slow regex checks
max_regex_len=20000

if [[ ! -f "$EXPIRE_FILE" ]]; then
    echo "Expire file not found, assuming no changed tiles"
    exit 0
fi

declare -A y_by_zx
declare -A x_by_z

tiles_to_expire_count=$(wc -l < $EXPIRE_FILE)
echo "Processing $tiles_to_expire_count expired tiles..."

# Read and organize expired tiles
while IFS= read -r tile; do
    [[ -z "$tile" ]] && continue
    z="${tile%%/*}"
    rest="${tile#*/}"
    x="${rest%%/*}"
    y="${rest#*/}"

    y_by_zx["$z|$x"]+="$y "
    x_by_z["$z"]+="$x "
done < "$EXPIRE_FILE"

# Input: space-separated sorted numbers
# Output: pipe-separated ranges like "10-12|15-16|18"
numbers_to_ranges() {
    local nums=("$@")
    local start="" end="" range_str=""

    for n in "${nums[@]}"; do
        if [ -z "$start" ]; then
            start="$n"
            end="$n"
        elif [ $((n)) -eq $((end + 1)) ]; then
            end="$n"
        else
            # Add previous range
            if [ "$start" -eq "$end" ]; then
                range_str+="$start|"
            else
                range_str+="$start-$end|"
            fi
            start="$n"
            end="$n"
        fi
    done

    # Add last range
    if [ -n "$start" ]; then
        if [ "$start" -eq "$end" ]; then
            range_str+="$start"
        else
            range_str+="$start-$end"
        fi
    fi

    echo "$range_str"
}

# Issue one or more bans per zoom level
for z in "${!x_by_z[@]}"; do
    # Sort x coordinates numerically to improve regex performance
    x_array=($(echo "${x_by_z[$z]}" | tr ' ' '\n' | sort -n))

    total_x_values=${#x_array[@]}
    start=0

    while [ $start -lt $total_x_values ]; do
        regex_parts=""

        for ((i=start; i<total_x_values; i++)); do
            x="${x_array[i]}"
            space_sep_y_values="${y_by_zx[$z|$x]}"
            read -r -a y_values <<< "$(echo "$space_sep_y_values" | tr ' ' '\n' | sort -n)"
            # Compress consecutive numbers into ranges
            range_str=$(numbers_to_ranges "${y_values[@]}")
            nested_part="${x}/(${range_str})"

            # add the result even if we might go past our max length, otherwise we'll get an infinite loop if we exceed the limit in one iteration
            regex_parts+="${nested_part}|"
            
            if (( ${#regex_parts} > max_regex_len )); then
                # i won't increment automatically once we break, so do it manually
                i=$((i + 1))
                break
            fi
        done

        regex_parts="${regex_parts%|}"
        # Example: /beefsteak/12/(10/(10|11|12)|11/(10|11|12))
        full_regex="^${PREFIX}/${z}/(${regex_parts})$"

        echo "Running ban for z $z, x_array $((start+1))-$((i))..."
        # Make sure to key off of `obj` only in order for the ban lurker to work
        $VARNISHADM \
            -T $ADMIN_ADDR \
            -S $SECRET \
            ban "obj.http.x-url ~ ${full_regex} && obj.ttl > 0s"

        start=$i
    done
done

# Delete to expire file to mark the changes as seen and handled
rm $EXPIRE_FILE

echo "Done processing expired tiles"