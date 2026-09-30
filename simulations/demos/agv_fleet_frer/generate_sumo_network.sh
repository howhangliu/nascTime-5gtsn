#!/usr/bin/env bash
set -euo pipefail

demo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
netconvert --node-files "$demo_dir/agv_fleet.nod.xml" \
    --edge-files "$demo_dir/agv_fleet.edg.xml" \
    --output-file "$demo_dir/agv_fleet.net.xml" \
    --offset.disable-normalization true \
    --junctions.corner-detail 0
tripinfo_file="$(mktemp)"
trap 'rm -f "$tripinfo_file"' EXIT
sumo -c "$demo_dir/agv_fleet.sumocfg" \
    --end 620 \
    --tripinfo-output "$tripinfo_file" \
    --tripinfo-output.write-unfinished true \
    --no-step-log true

# All ten UEs must still exist when OMNeT++ reaches its 620 s limit. If a
# vehicle arrives earlier, Veins removes its compound NrNicUeDC module during
# the run and Simu5G's dynamic bearer cleanup invalidates a submodule iterator.
tripinfo_count="$(grep -c '<tripinfo ' "$tripinfo_file" || true)"
if [ "$tripinfo_count" -ne 10 ]; then
    echo "Expected 10 SUMO vehicles in validation output, found $tripinfo_count." >&2
    exit 1
fi
if grep -Eq 'arrival="[0-9]' "$tripinfo_file"; then
    echo "A SUMO vehicle finishes before the 620 s simulation horizon:" >&2
    grep -E 'arrival="[0-9]' "$tripinfo_file" >&2
    exit 1
fi
echo "Generated and validated $demo_dir/agv_fleet.net.xml"
