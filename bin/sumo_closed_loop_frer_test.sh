#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nasctime_root="$(cd "$script_dir/.." && pwd)"
workspace_root="$(cd "$nasctime_root/.." && pwd)"
scenario_dir="$nasctime_root/simulations/demos/sumo_closed_loop_frer"

omnetpp_root="${OMNETPP_ROOT:-$workspace_root/omnetpp-6.4.0}"
inet_root="${INET_ROOT:-$workspace_root/inet}"
simu5g_root="${SIMU5G_ROOT:-$workspace_root/simu5g}"
veins_root="${VEINS_ROOT:-$workspace_root/veins}"
veins_inet_root="${VEINS_INET_ROOT:-$veins_root/subprojects/veins_inet}"

for dependency_dir in "$omnetpp_root" "$inet_root" "$simu5g_root" "$veins_root" "$veins_inet_root"; do
    if [ ! -d "$dependency_dir" ]; then
        echo "Missing dependency directory: $dependency_dir" >&2
        exit 1
    fi
done

sumo_bin="${SUMO_BIN:-$(command -v sumo || true)}"
netconvert_bin="${NETCONVERT_BIN:-$(command -v netconvert || true)}"
if [ -z "$sumo_bin" ] || [ -z "$netconvert_bin" ]; then
    echo "SUMO and netconvert must be on PATH." >&2
    exit 1
fi

source "$omnetpp_root/setenv" -q >/dev/null
# opp_env OMNeT++ bundles guard their Makefile with this marker. A real
# opp_env shell already supplies it; direct installations do not need it.
if grep -q 'ifndef OPP_ENV_VERSION' "$omnetpp_root/Makefile.inc" && [ -z "${OPP_ENV_VERSION:-}" ]; then
    export OPP_ENV_VERSION="nasctime-script"
fi
export INET_ROOT="$inet_root" SIMU5G_ROOT="$simu5g_root" VEINS_ROOT="$veins_root"
export PATH="$(dirname "$sumo_bin"):$veins_root/bin:$PATH"

"$scenario_dir/generate_sumo_network.sh"
mkdir -p "$scenario_dir/results"

launchd_log="$scenario_dir/results/veins_launchd.log"
veins_launchd -vv --port 9999 --command "$sumo_bin" >"$launchd_log" 2>&1 &
launchd_pid=$!
cleanup() {
    kill "$launchd_pid" 2>/dev/null || true
    wait "$launchd_pid" 2>/dev/null || true
}
trap cleanup EXIT

launchd_ready=false
for _ in {1..50}; do
    if grep -qi "listening on port 9999" "$launchd_log" 2>/dev/null; then
        launchd_ready=true
        break
    fi
    if ! kill -0 "$launchd_pid" 2>/dev/null; then
        tail -40 "$launchd_log" >&2
        exit 1
    fi
    sleep 0.1
done
if [ "$launchd_ready" != true ]; then
    echo "veins_launchd did not become ready on port 9999" >&2
    tail -40 "$launchd_log" >&2
    exit 1
fi

make -C "$nasctime_root" INET_ROOT="$inet_root" SIMU5G_ROOT="$simu5g_root"

rm -f "$scenario_dir/results/SumoClosedLoopUplinkFrer_run0.sca" \
      "$scenario_dir/results/SumoClosedLoopUplinkFrer_run0.vec"

ned_path="$nasctime_root/src:$nasctime_root/simulations:$simu5g_root/src:$inet_root/src:$veins_root/src/veins:$veins_inet_root/src/veins_inet"
(
    cd "$scenario_dir"
    opp_run -u Cmdenv -c SumoClosedLoopUplinkFrer \
        -n "$ned_path" \
        -l "$nasctime_root/src/nasctime" \
        -l "$veins_root/src/veins" \
        -l "$veins_inet_root/src/veins_inet" \
        -f omnetpp.ini
)

sca="$scenario_dir/results/SumoClosedLoopUplinkFrer_run0.sca"
test -s "$sca"
reporter_count="$(grep -Ec '^scalar .*car\[[0-9]+\]\.positionSource\.app\[0\] "packets sent" [1-9]' "$sca" || true)"
test "$reporter_count" -eq 10
if grep -Eq '^scalar .*car\[[0-9]+\]\.positionSource\.ipv4\.ip packetDropNoRouteFound:count [1-9]' "$sca"; then
    echo "Position reports were dropped because a vehicle source has no route." >&2
    exit 1
fi
if grep -Eq '^scalar .*car\[[0-9]+\]\.eth\[0\]\.mac packetDropNotAddressedToUs:count [1-9]' "$sca"; then
    echo "FRER copies were rejected by a vehicle UE Ethernet MAC." >&2
    exit 1
fi
grep -Eq '^scalar .*frerReplicatorUl primarySent:count [1-9]' "$sca"
grep -Eq '^scalar .*frerReplicatorUl replicaSent:count [1-9]' "$sca"
grep -Eq '^scalar .*nwTt\.frerRecoveryUl duplicatesDropped:count [1-9]' "$sca"
grep -Eq '^scalar .*tsnServer\.app\[0\] packetReceived:count [1-9]' "$sca"

echo "SUMO closed-loop uplink FRER test passed ($reporter_count vehicle reporters)."
echo "Results: $scenario_dir/results"
