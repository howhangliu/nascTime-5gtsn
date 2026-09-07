#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/sumo_closed_loop_frer_test.sh" SumoClosedLoopUplinkFrerPartialOverlap
