#!/bin/bash
#
# run_matrix.sh — Launch the MSWiM 2026 experiment matrix in parallel.
#
# Dispatches one opp_run process per (Config, run number) cell. Run numbers
# correspond to (sched, repetition) iteration combinations enumerated by
# opp_run -q runs. Uses GNU parallel with JOBS workers. Resumable: skips
# cells whose .sca already exists.
#
# Usage:
#   ./run_matrix.sh [primary|fading|gptp|pilot|all]
#
# Environment overrides:
#   JOBS=4           number of parallel simulations
#   SIMU5G_DIR=...   path to Simu5G src tree (relative to script dir)
#   INET_DIR=...     path to INET src tree
#

set -euo pipefail

# chdir to script location so relative paths always resolve correctly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

JOBS="${JOBS:-4}"
SIMU5G_DIR="${SIMU5G_DIR:-../../../../src}"
INET_DIR="${INET_DIR:-../../../../../inet-4.6.0/src}"
NED_SIM_DIR="${NED_SIM_DIR:-../../../../simulations}"
WHICH="${1:-primary}"

if ! command -v parallel >/dev/null 2>&1; then
    echo "FAIL: GNU parallel not installed (apt install parallel)"
    exit 1
fi

# ----------------------------------------------------------------------------
# Run number layout per Config
# ----------------------------------------------------------------------------
# SweepBase / Gptp* configs: 5 schedulers x 3 reps = 15 runs (0..14)
#   Runs 0-2:   MAXCI
#   Runs 3-5:   PF
#   Runs 6-8:   DRR
#   Runs 9-11:  MAXCI_COMP
#   Runs 12-14: QOS_PF
#
# Fade* configs: 2 schedulers x 2 fading x 3 reps = 12 runs (0..11)
#   Runs 0-2:   MAXCI fade=false
#   Runs 3-5:   MAXCI fade=true
#   Runs 6-8:   QOS_PF fade=false
#   Runs 9-11:  QOS_PF fade=true
#
# These mappings let us derive a stable filename from the run number even
# without parsing opp_run's output.

# Map run number to (sched, rep) for primary/gptp configs
sched_for_run_5() {
    local r=$1
    case $((r / 3)) in
        0) echo MAXCI ;;
        1) echo PF ;;
        2) echo DRR ;;
        3) echo MAXCI_COMP ;;
        4) echo QOS_PF ;;
    esac
}
rep_for_run() { echo $(($1 % 3)); }

# Map run number to (sched, fade, rep) for fading configs
sched_for_run_fade() {
    local r=$1
    if (( r < 6 )); then echo MAXCI; else echo QOS_PF; fi
}
fade_for_run() {
    local r=$1
    case $(( (r / 3) % 2 )) in
        0) echo false ;;
        1) echo true ;;
    esac
}

# ----------------------------------------------------------------------------
# Cell enumeration: prints "config runnum" per line
# ----------------------------------------------------------------------------
enumerate_primary() {
    for cfg in Sweep_N40; do
        for r in $(seq 0 14); do
            echo "$cfg $r"
        done
    done
}

enumerate_fading() {
    for cfg in Fade_N1 Fade_N10 Fade_N20; do
        for r in $(seq 0 11); do
            echo "$cfg $r"
        done
    done
}

enumerate_gptp() {
    for cfg in Gptp_N1 Gptp_N10 Gptp_N20; do
        for r in $(seq 0 14); do
            echo "$cfg $r"
        done
    done
}

enumerate_pilot() {
    # MS4 pilot: only Sweep_N5, all 15 runs
    for r in $(seq 0 14); do
        echo "Sweep_N5 $r"
    done
}

# ----------------------------------------------------------------------------
# Worker: run a single cell
# Args: config runnum
# ----------------------------------------------------------------------------
run_cell() {
    local config="$1" runnum="$2"

    local resdir kind
    case "$config" in
        Sweep_*) resdir="results/sweep_primary"; kind="primary" ;;
        Fade_*)  resdir="results/sweep_fading";  kind="fading"  ;;
        Gptp_*)  resdir="results/sweep_gptp";    kind="gptp"    ;;
        *) echo "[FAIL] unknown config $config"; return 1 ;;
    esac
    mkdir -p "$resdir"

    # The .sca filename produced by OMNeT++ uses ${runnumber}
    local sca="${resdir}/${config}_run${runnum}.sca"
    if [ -f "$sca" ]; then
        echo "[SKIP] ${config}_run${runnum}"
        return 0
    fi

    # For pretty status output, derive scheduler and repetition from runnum
    local sched rep extra
    if [ "$kind" = "fading" ]; then
        sched=$(sched_for_run_fade "$runnum")
        rep=$(rep_for_run "$runnum")
        local fade=$(fade_for_run "$runnum")
        extra="${sched}/fade=${fade}/r${rep}"
    else
        sched=$(sched_for_run_5 "$runnum")
        rep=$(rep_for_run "$runnum")
        extra="${sched}/r${rep}"
    fi
    local tag="${config}_run${runnum}"

    local start=$(date +%s)
    if opp_run \
        -u Cmdenv \
        -c "$config" \
        -r "$runnum" \
        -f omnetpp_sweep.ini \
        -n "${NED_SIM_DIR}:${SIMU5G_DIR}:${INET_DIR}" \
        -l "${SIMU5G_DIR}/simu5g" \
        -l "${INET_DIR}/INET" \
        > "${resdir}/${tag}.stdout" 2>&1
    then
        local elapsed=$(( $(date +%s) - start ))
        echo "[DONE] $tag [$extra] (${elapsed}s)"
    else
        echo "[FAIL] $tag [$extra] — see ${resdir}/${tag}.stdout"
        return 1
    fi
}
export -f run_cell sched_for_run_5 sched_for_run_fade rep_for_run fade_for_run
export SIMU5G_DIR INET_DIR NED_SIM_DIR

# ----------------------------------------------------------------------------
# Dispatch
# ----------------------------------------------------------------------------
case "$WHICH" in
    primary) ENUM=enumerate_primary ;;
    fading)  ENUM=enumerate_fading  ;;
    gptp)    ENUM=enumerate_gptp    ;;
    pilot)   ENUM=enumerate_pilot   ;;
    all)
        "$0" primary
        "$0" fading
        "$0" gptp
        exit 0
        ;;
    *)
        echo "Usage: $0 [primary|fading|gptp|pilot|all]"
        exit 2
        ;;
esac

TOTAL=$($ENUM | wc -l)
echo "==> Dispatching $TOTAL $WHICH cells with $JOBS parallel workers"
echo "    NED_SIM_DIR = $NED_SIM_DIR"
echo "    SIMU5G_DIR  = $SIMU5G_DIR"
echo "    INET_DIR    = $INET_DIR"
echo ""

$ENUM | parallel --jobs "$JOBS" --colsep ' ' --line-buffer \
    run_cell {1} {2}

echo ""
echo "==> $WHICH sweep complete"
