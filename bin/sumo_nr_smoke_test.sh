#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NASCTIME_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$NASCTIME_ROOT/.." && pwd)"
SCENARIO_DIR="$NASCTIME_ROOT/simulations/demos/sumo_nr"

OMNETPP_ROOT="${OMNETPP_ROOT:-$WORKSPACE_ROOT/omnetpp-6.4.0}"
INET_ROOT="${INET_ROOT:-$WORKSPACE_ROOT/inet}"
SIMU5G_ROOT="${SIMU5G_ROOT:-$WORKSPACE_ROOT/simu5g}"
VEINS_ROOT="${VEINS_ROOT:-$WORKSPACE_ROOT/veins}"
VEINS_INET_ROOT="${VEINS_INET_ROOT:-$VEINS_ROOT/subprojects/veins_inet}"

for path in "$OMNETPP_ROOT" "$INET_ROOT" "$SIMU5G_ROOT" "$VEINS_ROOT" "$VEINS_INET_ROOT"; do
    if [ ! -d "$path" ]; then
        echo "Missing dependency directory: $path" >&2
        exit 1
    fi
done

SUMO_BIN="${SUMO_BIN:-$(command -v sumo || true)}"
NETCONVERT_BIN="${NETCONVERT_BIN:-$(command -v netconvert || true)}"
if [ -z "$SUMO_BIN" ] || [ ! -x "$SUMO_BIN" ] || [ -z "$NETCONVERT_BIN" ] || [ ! -x "$NETCONVERT_BIN" ]; then
    echo "SUMO 1.22.0 and netconvert must be on PATH (Veins 5.3.1 supports TraCI API through 21)." >&2
    echo "A local Python environment can provide both commands:" >&2
    echo "  python3 -m venv <sumo-venv>" >&2
    echo "  <sumo-venv>/bin/python -m pip install eclipse-sumo==1.22.0" >&2
    echo "  source <sumo-venv>/bin/activate" >&2
    exit 1
fi

# OMNeT++ setenv reads its optional first argument directly. Passing its
# supported quiet flag keeps this safe while this script has `set -u` enabled.
source "$OMNETPP_ROOT/setenv" -q >/dev/null
export INET_ROOT SIMU5G_ROOT VEINS_ROOT
export PATH="$(dirname "$SUMO_BIN"):$VEINS_ROOT/bin:$PATH"

mkdir -p "$SCENARIO_DIR/results"
"$NETCONVERT_BIN" \
    --node-files "$SCENARIO_DIR/straight.nod.xml" \
    --edge-files "$SCENARIO_DIR/straight.edg.xml" \
    --output-file "$SCENARIO_DIR/straight.net.xml" \
    --no-turnarounds true

LAUNCHD_LOG="$SCENARIO_DIR/results/veins_launchd.log"
veins_launchd -vv --port 9999 --command "$SUMO_BIN" >"$LAUNCHD_LOG" 2>&1 &
LAUNCHD_PID=$!
cleanup() {
    kill "$LAUNCHD_PID" 2>/dev/null || true
    wait "$LAUNCHD_PID" 2>/dev/null || true
}
trap cleanup EXIT

LAUNCHD_READY=false
for _ in {1..50}; do
    if grep -qi "listening on port 9999" "$LAUNCHD_LOG" 2>/dev/null; then
        LAUNCHD_READY=true
        break
    fi
    if ! kill -0 "$LAUNCHD_PID" 2>/dev/null; then
        echo "veins_launchd exited before accepting connections" >&2
        tail -40 "$LAUNCHD_LOG" >&2
        exit 1
    fi
    sleep 0.1
done
if [ "$LAUNCHD_READY" != true ]; then
    echo "veins_launchd did not become ready on port 9999" >&2
    tail -40 "$LAUNCHD_LOG" >&2
    exit 1
fi

cd "$SCENARIO_DIR"
rm -f results/SumoNr.sca results/SumoNr.vec results/mobility.csv

NED_PATH="$NASCTIME_ROOT/src:$NASCTIME_ROOT/simulations:$SIMU5G_ROOT/src:$INET_ROOT/src:$VEINS_ROOT/src/veins:$VEINS_INET_ROOT/src/veins_inet"
opp_run -u Cmdenv \
    -n "$NED_PATH" \
    -l "$NASCTIME_ROOT/src/nasctime" \
    -l "$VEINS_ROOT/src/veins" \
    -l "$VEINS_INET_ROOT/src/veins_inet" \
    -f omnetpp.ini

test -s results/mobility.csv
grep -q ',car\[0\],' results/mobility.csv
grep -q 'packetReceived:count' results/SumoNr.sca

echo "SUMO NR smoke test passed"
echo "Mobility trace: $SCENARIO_DIR/results/mobility.csv"
