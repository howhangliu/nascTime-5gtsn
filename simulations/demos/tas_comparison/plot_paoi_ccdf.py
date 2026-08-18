#!/usr/bin/env python3
"""Peak-AoI CCDF of the critical stream across the 5G-TSN bridge.

Run both configurations first, then this script::

    ../../../bin/nasctime-run -u Cmdenv -c Baseline -f omnetpp.ini
    ../../../bin/nasctime-run -u Cmdenv -c Tas -f omnetpp.ini
    ./plot_paoi_ccdf.py
"""

from __future__ import annotations

import sys
from pathlib import Path

DEMO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(DEMO_DIR.parents[1] / "analysis"))

from paoi import CcdfFigure, RunSpec, Scenario  # noqa: E402


RECEIVER = "TasComparisonNetwork.tsnDeviceB.app[0]"  # the critical-stream sink

SCENARIO = Scenario(
    name="5g-tsn",
    title="Critical stream over the 5G-TSN bridge",
    runs=(
        RunSpec(DEMO_DIR / "results/baseline/Baseline-#0.vec", RECEIVER, "Baseline (FIFO)"),
        RunSpec(DEMO_DIR / "results/tas/Tas-#0.vec", RECEIVER, "TAS"),
    ),
)


def main() -> int:
    missing = SCENARIO.missing()
    if missing:
        print("error: result file(s) not found:", file=sys.stderr)
        for path in missing:
            print(f"  {path}", file=sys.stderr)
        print("Run the Baseline and Tas configurations first.", file=sys.stderr)
        return 1

    figure = CcdfFigure(SCENARIO.title)
    for series in SCENARIO.peak_series():
        figure.add(series)
        print(series.summary())

    output = DEMO_DIR / "figures" / f"paoi-ccdf-{SCENARIO.name}.pdf"
    for path in figure.save(output, output.with_suffix(".png")):
        print(f"figure: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
