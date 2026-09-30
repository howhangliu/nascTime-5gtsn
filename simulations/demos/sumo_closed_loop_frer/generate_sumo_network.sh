#!/usr/bin/env bash
set -euo pipefail

demo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v netconvert >/dev/null 2>&1; then
    echo "netconvert was not found. Install/source SUMO before running this script." >&2
    exit 1
fi

netconvert \
    --node-files "$demo_dir/square.nod.xml" \
    --edge-files "$demo_dir/square.edg.xml" \
    --output-file "$demo_dir/square.net.xml" \
    --no-turnarounds true \
    --junctions.corner-detail 0

# A short normal run forces SUMO to parse the generated network and the full
# route file. Avoid --check-route-files: it is not available in all supported
# SUMO releases.
sumo -c "$demo_dir/square.sumocfg" --end 0.01 --no-step-log true
echo "Generated and validated $demo_dir/square.net.xml"
