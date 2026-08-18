#!/usr/bin/env python3
"""Plot receiver Age of Information from an OMNeT++ vector file.

The AoI reconstruction lives in ``simulations/analysis/paoi``; this script is
the uplink scenario's front end to it, adding the phase annotations that make
the SINR-failover run readable.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "analysis"))

from paoi import AoiTimelineFigure, AoiTrace, VectorFile  # noqa: E402


BAD_COLOR = "#e34948"
SWITCH_COLOR = "#008300"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vec", type=Path, help="OMNeT++ .vec result file")
    parser.add_argument("--stream", type=int, default=0,
                        help="receiver app/UDP stream: 0=DSCP 6, 1=best effort (default: 0)")
    parser.add_argument("--network", default="UplinkNetwork",
                        help="network name, for building the receiver module path")
    parser.add_argument("--receiver", default="tsnDeviceA",
                        help="receiving node name (default: tsnDeviceA)")
    parser.add_argument("--output", type=Path, help="output PNG path")
    parser.add_argument("--bad-at", type=float,
                        help="mark the time when channel quality becomes bad")
    parser.add_argument("--switch-at", type=float,
                        help="mark the time when traffic switches path")
    parser.add_argument("--max-time", type=float,
                        help="override the plot/simulation end time")
    parser.add_argument("--ccdf", action="store_true",
                        help="also write a peak-AoI CCDF beside the timeline")
    args = parser.parse_args()

    module = f"{args.network}.{args.receiver}.app[{args.stream}]"
    output = args.output or args.vec.with_name(f"{args.vec.stem}-aoi-stream{args.stream}.png")
    csv_path = output.with_suffix(".peaks.csv")

    vectors = VectorFile(args.vec)
    try:
        trace = AoiTrace.from_vector_file(vectors, module, args.max_time)
    except ValueError as error:
        raise SystemExit(f"error: {error}") from None

    plot_end = args.max_time or vectors.sim_time_limit or trace.points[-1][0]
    # A wide canvas gives each experiment phase enough horizontal room for
    # the dense per-packet AoI sawtooth to remain visually distinguishable.
    figure = AoiTimelineFigure(f"Age of Information — {args.vec.stem}, stream {args.stream}")
    figure.add(trace)
    if args.bad_at is not None:
        bad_end = args.switch_at if args.switch_at is not None else plot_end
        figure.mark_span(args.bad_at, bad_end, "degraded active path", BAD_COLOR)
    if args.switch_at is not None:
        figure.mark_span(args.switch_at, plot_end, "traffic on standby path", SWITCH_COLOR)
    figure.finish(plot_end)
    figure.save(output, dpi=180)

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["simulation_time_s", "peak_aoi_s", "peak_aoi_ms", "received_sequence"])
        writer.writerows((peak.time, peak.value, peak.value * 1000, peak.sequence)
                         for peak in trace.peaks)

    series = trace.peak_series(f"stream {args.stream}")
    print(f"Received updates: {len(trace.receptions)}")
    print(f"AoI peaks: {len(trace.peaks)}")
    print(series.summary())
    print(f"Plot: {output}")
    print(f"Peak data: {csv_path}")

    if args.ccdf:
        from paoi import CcdfFigure

        ccdf_path = output.with_name(f"{output.stem}-ccdf.pdf")
        ccdf = CcdfFigure(f"Peak AoI — {args.vec.stem}, stream {args.stream}")
        ccdf.add(series)
        ccdf.save(ccdf_path)
        print(f"CCDF: {ccdf_path}")


if __name__ == "__main__":
    main()
