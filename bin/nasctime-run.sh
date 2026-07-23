#!/usr/bin/env bash
#
# nasctime-run — generic wrapper for running any nascTime scenario via
# opp_run, now that nascTime builds as a shared library (libnasctime.so)
# rather than a standalone executable.
#
# Unlike run_matrix.sh/smoke_test.sh (which are tied to one specific
# scenario's own logic -- profile generation, custom result parsing),
# this wrapper is scenario-agnostic: it just sets up the correct
# LD_LIBRARY_PATH and NED/library paths, then hands off every argument
# to opp_run untouched.
#
# Usage: run from inside any scenario directory (e.g. tests/bridge_test/,
# simulations/demos/frer_test/), same as the old per-scenario `run` script:
#   ../../bin/nasctime-run -f omnetpp.ini [any other opp_run args]
# or from anywhere, via an absolute/relative path to this script.
#
# Environment overrides:
#   SIMU5G_SRC=...   absolute path to Simu5G src tree
#   INET_SRC=...     absolute path to INET src tree
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NASCTIME_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$NASCTIME_ROOT/.." && pwd)"

SIMU5G_SRC="${SIMU5G_SRC:-$WORKSPACE_ROOT/simu5g-1.5.0/src}"
INET_SRC="${INET_SRC:-$WORKSPACE_ROOT/inet-4.6.0/src}"
NASCTIME_SRC="$NASCTIME_ROOT/src"
NED_ROOTS="$NASCTIME_SRC:$NASCTIME_ROOT/tests:$NASCTIME_ROOT/simulations"

if [ ! -d "$SIMU5G_SRC" ]; then
    echo "nasctime-run: Simu5G src not found at $SIMU5G_SRC (override with SIMU5G_SRC=...)" >&2
    exit 1
fi
if [ ! -d "$INET_SRC" ]; then
    echo "nasctime-run: INET src not found at $INET_SRC (override with INET_SRC=...)" >&2
    exit 1
fi
if [ ! -f "$NASCTIME_SRC/libnasctime.so" ]; then
    echo "nasctime-run: libnasctime.so not found at $NASCTIME_SRC (build nascTime first: cd $NASCTIME_ROOT && make)" >&2
    exit 1
fi

export LD_LIBRARY_PATH="$NASCTIME_SRC:${LD_LIBRARY_PATH:-}"

exec opp_run \
    -n "$NED_ROOTS:$SIMU5G_SRC:$INET_SRC" \
    -l nasctime \
    -l "$SIMU5G_SRC/simu5g" \
    -l "$INET_SRC/INET" \
    "$@"

