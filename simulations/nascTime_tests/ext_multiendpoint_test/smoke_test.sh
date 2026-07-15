#!/bin/bash
#
# smoke_test.sh — Validate the heterogeneous traffic generator
#                     end-to-end on a single small scenario.
#
# This script:
#   1. Generates all profile fragments (profiles_N{N}.ini)
#   2. Builds the project (assumes you've configured opp_makemake)
#   3. Runs the N=5 heterogeneous scenario
#   4. Inspects the results to confirm packets flow on every profile
#
# Run from the multi_endpoint_test directory.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="${SIM_DIR:-$(pwd)}"
INET_DIR="${INET_DIR:-../../../../../inet-4.6.0/src}"
SIMU5G_DIR="${SIMU5G_DIR:-../../../../src}"
RESULTS_DIR="${RESULTS_DIR:-results/hetero}"
CONFIG="${CONFIG:-Hetero_N5}"
NETWORK_PREFIX="${NETWORK_PREFIX:-ExtendedMultiEndpointNetwork}"
 
echo "==> MS1 smoke test"
echo "    CONFIG      = $CONFIG"
echo "    RESULTS_DIR = $RESULTS_DIR"
echo "    NETWORK     = $NETWORK_PREFIX"
echo ""

# ----------------------------------------------------------------------------
# Step 1: regenerate profile fragments
# ----------------------------------------------------------------------------
echo "==> Step 1: regenerating profile fragments"
mkdir -p profiles
python3 gen_profile_ini.py --all -o profiles/
ls -la profiles/

# ----------------------------------------------------------------------------
# Step 2: validate generator output structure
# ----------------------------------------------------------------------------
echo ""
echo "==> Step 2: validating generator output"
for n in 1 5 10 15 20; do
    f="profiles/profiles_N${n}.ini"
    if [ ! -f "$f" ]; then
        echo "    FAIL: $f not generated"
        exit 1
    fi
    apps=$(grep -c "tsnDeviceA.app\[" "$f" || true)
    echo "    N=$n: $apps app entries in $f"
done

# Sanity check: N=5 should have:
#   2 CLC × 1 flow + 2 MV × 2 flows + 1 BLK × 1 flow = 7 generators + 1 sink = 8
n5_apps=$(grep -c "tsnDeviceA.app\[" profiles/profiles_N5.ini)
if [ "$n5_apps" -lt "$((8 * 7))" ]; then
    echo "    Expected at least 56 app config lines for N=5, got $n5_apps"
    # Note: each app has ~7 config lines (typename, dest, port, etc.)
fi

# ----------------------------------------------------------------------------
# Step 3: run the scenario
# ----------------------------------------------------------------------------
echo ""
echo "==> Step 3: running $CONFIG"

rm -rf "$RESULTS_DIR"
 
if ! opp_run -u Cmdenv \
    -c "$CONFIG" \
    -f ex_multi_omnetpp.ini \
    -n "../../../../simulations:${SIMU5G_DIR}:${INET_DIR}" \
    -l "${SIMU5G_DIR}/simu5g" \
    -l "${INET_DIR}/INET" \
    > ms1_smoke.log 2>&1; then
    echo "    FAIL: opp_run exited with non-zero status"
    echo "    See ms1_smoke.log for details"
    tail -40 ms1_smoke.log
    exit 1
fi

# ----------------------------------------------------------------------------
# Step 4: locate the .sca file
# ----------------------------------------------------------------------------
echo ""
echo "==> Step 4: locating results"
SCA_FILE=$(find "$RESULTS_DIR" -name "${CONFIG}-*.sca" 2>/dev/null | head -1)
if [ -z "$SCA_FILE" ] || [ ! -f "$SCA_FILE" ]; then
    echo "    FAIL: no .sca file found under $RESULTS_DIR"
    exit 1
fi
echo "    Found: $SCA_FILE"
 
# ----------------------------------------------------------------------------
# Step 5: extract packet counts
# ----------------------------------------------------------------------------
echo ""
echo "==> Step 5: extracting packet counts from .sca"
 
# Helper: grep a scalar line and print its value.
# OMNeT++ .sca format: scalar <module> <name> <value>
# Module names may contain brackets; we grep as a literal prefix match.
sca_get() {
    local module="$1"
    local name="$2"
    awk -v m="$module" -v n="$name" '
        $1 == "scalar" && $2 == m && $3 == n { print $4; exit }
    ' "$SCA_FILE"
}
 
# Per-endpoint Device B sink counts
declare -A RX
for ep in 0 1 2 3 4; do
    for app in 0 1 2; do
        mod="${NETWORK_PREFIX}.tsnDeviceB[${ep}].app[${app}]"
        count=$(sca_get "$mod" "packetReceived:count")
        if [ -n "$count" ]; then
            RX["${ep}.${app}"]=$count
        fi
    done
done
 
# Device A reverse sink (fixed at app[7] for N=5)
REV=$(sca_get "${NETWORK_PREFIX}.tsnDeviceA.app[7]" "packetReceived:count")
 
echo ""
echo "    Endpoint 0 (CLC):  app[0]=${RX[0.0]:-MISSING}"
echo "    Endpoint 1 (CLC):  app[0]=${RX[1.0]:-MISSING}"
echo "    Endpoint 2 (MV):   app[0]=${RX[2.0]:-MISSING}  app[1]=${RX[2.1]:-MISSING}"
echo "    Endpoint 3 (MV):   app[0]=${RX[3.0]:-MISSING}  app[1]=${RX[3.1]:-MISSING}"
echo "    Endpoint 4 (BLK):  app[0]=${RX[4.0]:-MISSING}"
echo "    Device A reverse:  ${REV:-MISSING}"
 
# ----------------------------------------------------------------------------
# Step 6: pass/fail check
# ----------------------------------------------------------------------------
echo ""
echo "==> Step 6: pass/fail check"
 
PASS=true
 
check_ge() {
    local label="$1"
    local value="$2"
    local min="$3"
    if [ -z "$value" ]; then
        printf "    %-28s FAIL (missing)\n" "$label"
        PASS=false
    elif [ "${value%.*}" -lt "$min" ]; then
        printf "    %-28s FAIL (%s < %s)\n" "$label" "$value" "$min"
        PASS=false
    else
        printf "    %-28s PASS (%s)\n" "$label" "$value"
    fi
}
 
# Expected values for a 10s run with 1s warmup (~9s effective)
check_ge "Endpoint 0 CLC HP"     "${RX[0.0]:-}"  9000
check_ge "Endpoint 1 CLC HP"     "${RX[1.0]:-}"  9000
check_ge "Endpoint 2 MV HP"      "${RX[2.0]:-}"  1800
check_ge "Endpoint 2 MV BE"      "${RX[2.1]:-}"  4000
check_ge "Endpoint 3 MV HP"      "${RX[3.0]:-}"  1800
check_ge "Endpoint 3 MV BE"      "${RX[3.1]:-}"  4000
check_ge "Endpoint 4 BLK"        "${RX[4.0]:-}"  800
check_ge "Device A reverse"      "${REV:-}"      3500
 
if $PASS; then
    echo ""
    echo "==> MS1 SMOKE TEST PASSED"
    exit 0
else
    echo ""
    echo "==> MS1 SMOKE TEST FAILED"
    echo ""
    echo "Debug: all 'received' scalars in .sca:"
    grep "packetReceived:count" "$SCA_FILE" | head -20
    exit 1
fi
 
