#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nasctime_root="$(cd "$script_dir/.." && pwd)"
workspace_root="$(cd "$nasctime_root/.." && pwd)"
scenario_dir="$nasctime_root/simulations/demos/agv_fleet_frer"
omnetpp_root="${OMNETPP_ROOT:-$workspace_root/omnetpp-6.4.0}"
inet_root="${INET_ROOT:-$workspace_root/inet}"
simu5g_root="${SIMU5G_ROOT:-$workspace_root/simu5g}"
veins_root="${VEINS_ROOT:-$workspace_root/veins}"
veins_inet_root="${VEINS_INET_ROOT:-$veins_root/subprojects/veins_inet}"
sumo_bin="${SUMO_BIN:-$(command -v sumo || true)}"

if [ -z "$sumo_bin" ] || ! command -v netconvert >/dev/null 2>&1; then
    echo "SUMO and netconvert must be on PATH." >&2
    exit 1
fi

source "$omnetpp_root/setenv" -q >/dev/null
if grep -q 'ifndef OPP_ENV_VERSION' "$omnetpp_root/Makefile.inc" && [ -z "${OPP_ENV_VERSION:-}" ]; then
    export OPP_ENV_VERSION="nasctime-script"
fi
export INET_ROOT="$inet_root" SIMU5G_ROOT="$simu5g_root" VEINS_ROOT="$veins_root"
export PATH="$(dirname "$sumo_bin"):$veins_root/bin:$PATH"

"$scenario_dir/generate_sumo_network.sh"
make -C "$nasctime_root" INET_ROOT="$inet_root" SIMU5G_ROOT="$simu5g_root"

mkdir -p "$scenario_dir/results"
launchd_log="$scenario_dir/results/veins_launchd.log"
veins_launchd -vv --port 9999 --command "$sumo_bin" >"$launchd_log" 2>&1 &
launchd_pid=$!
trap 'kill "$launchd_pid" 2>/dev/null || true; wait "$launchd_pid" 2>/dev/null || true' EXIT

for _ in {1..50}; do
    grep -qi "listening on port 9999" "$launchd_log" 2>/dev/null && break
    sleep 0.1
done

ned_path="$nasctime_root/src:$nasctime_root/simulations:$simu5g_root/src:$inet_root/src:$veins_root/src/veins:$veins_inet_root/src/veins_inet"
(
    cd "$scenario_dir"
    opp_run -u Cmdenv -c AgvFleetUplinkFrer -n "$ned_path" \
        -l "$nasctime_root/src/nasctime" -l "$veins_root/src/veins" \
        -l "$veins_inet_root/src/veins_inet" -f omnetpp.ini
)

test "$(find "$scenario_dir/results" -name 'AgvFleetUplinkFrer.sca' -size +0c | wc -l | tr -d ' ')" -eq 10
echo "AgvFleetUplinkFrer passed all ten seeds."
