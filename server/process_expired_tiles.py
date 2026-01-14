# We're doing this in python since it's much more performant than bash
# with memory and subprocesses for this type of work.

import subprocess
from collections import defaultdict
from pathlib import Path
from time import time, strftime, localtime

# Configuration
VARNISHADM = "/usr/local/varnish/bin/varnishadm"
ADMIN_ADDR = "127.0.0.1:6082"
SECRET = "/usr/local/varnish/etc/secret"
EXPIRE_FILE = "/var/lib/app/expired_tiles.txt"
PREFIX = "/beefsteak"
MAX_REGEX_LEN = 20000  # max length of regex string per ban

def timestamp():
    return strftime("%Y-%m-%d %H:%M:%S", localtime())

expire_path = Path(EXPIRE_FILE)
if not expire_path.exists():
    print(f"{timestamp()} - Expire file not found, assuming no changed tiles")
    exit(0)

start_time = time()

# Read tiles and group by z/x
y_by_zx = defaultdict(list)   # key: (z, x), value: list of y
x_by_z = defaultdict(set)     # key: z, value: set of x

tiles_to_expire_count = sum(1 for _ in expire_path.open())
print(f"{timestamp()} - Processing {tiles_to_expire_count} expired tiles...")

with expire_path.open() as f:
    for line in f:
        tile = line.strip()
        if not tile:
            continue
        z_str, x_str, y_str = tile.split("/")
        z, x, y = int(z_str), int(x_str), int(y_str)
        y_by_zx[(z, x)].append(y)
        x_by_z[z].add(x)

for key in y_by_zx:
    y_by_zx[key].sort()

def numbers_to_ranges(nums):
    if not nums:
        return ""
    ranges = []
    start = end = nums[0]
    for n in nums[1:]:
        if n == end + 1:
            end = n
        else:
            ranges.append(f"{start}" if start == end else f"{start}-{end}")
            start = end = n
    ranges.append(f"{start}" if start == end else f"{start}-{end}")
    return "|".join(ranges)

ranges_by_zx = {key: numbers_to_ranges(vals) for key, vals in y_by_zx.items()}

# --- Issue bans per zoom level ---
for z, x_set in x_by_z.items():
    x_list = sorted(x_set)
    total_x = len(x_list)
    start_idx = 0

    while start_idx < total_x:
        batch_start_time = time()
        regex_parts_list = []
        current_length = 0

        i = start_idx
        while i < total_x:
            x = x_list[i]
            range_str = ranges_by_zx[(z, x)]
            nested_part = f"{x}/({range_str})"
            regex_parts_list.append(nested_part)
            part_length = len(nested_part) + 1  # +1 for the "|" separator
            current_length += part_length

            i += 1  # always increment even if we're breaking

            if current_length > MAX_REGEX_LEN:
                break

        regex_parts = "|".join(regex_parts_list)
        full_regex = f"^{PREFIX}/{z}/({regex_parts})$"

        print(f"{timestamp()} - Running ban for z {z}, x indices {start_idx}-{i-1}...")
        subprocess.run([
            VARNISHADM,
            "-T", ADMIN_ADDR,
            "-S", SECRET,
            "ban", f"obj.http.x-url ~ {full_regex} && obj.ttl > 0s"
        ], check=True)

        batch_end_time = time()
        print(f"{timestamp()} - Batch duration: {batch_end_time - batch_start_time:.2f} seconds")

        start_idx = i

# Delete expire file
expire_path.unlink()

end_time = time()
print(f"{timestamp()} - Done processing expired tiles")
print(f"{timestamp()} - Total duration: {end_time - start_time:.2f} seconds")