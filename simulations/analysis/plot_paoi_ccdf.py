#!/usr/bin/env python3
"""Plot a peak-AoI CCDF from one or more OMNeT++ result files.

Each ``--run`` adds one curve, given as ``label=path/to/run.vec``. The
receiving application module is shared by every run in a figure::

    plot_paoi_ccdf.py --module TasComparisonNetwork.tsnDeviceB.app[0] \\
        --run "Baseline=results/baseline/Baseline-#0.vec" \\
        --run "TAS=results/tas/Tas-#0.vec" \\
        --output figures/paoi-ccdf.pdf
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from paoi import CcdfFigure, RunSpec  # noqa: E402


def parse_run(text: str, module: str) -> RunSpec:
    label, separator, path = text.partition("=")
    if not separator:
        raise argparse.ArgumentTypeError(f"--run needs 'label=path', got '{text}'")
    return RunSpec(vec=Path(path), module=module, label=label)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run", action="append", required=True, metavar="LABEL=VEC",
                        help="one curve; repeat for each configuration to compare")
    parser.add_argument("--module", required=True,
                        help="full path of the receiving application module")
    parser.add_argument("--output", type=Path, required=True,
                        help="output figure path; the suffix picks the format")
    parser.add_argument("--also-png", action="store_true",
                        help="write a PNG next to the requested output")
    parser.add_argument("--title", default="Peak age of information")
    parser.add_argument("--log-x", action="store_true", help="logarithmic x axis")
    parser.add_argument("--max-time", type=float,
                        help="override the run's own end time when closing the trace")
    parser.add_argument("--csv", action="store_true",
                        help="write per-curve CCDF data beside the figure")
    parser.add_argument("--check-stationarity", action="store_true",
                        help="also report each run's two halves, to show whether "
                             "the queue reached steady state")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    runs = [parse_run(text, args.module) for text in args.run]

    missing = [run.vec for run in runs if not run.vec.exists()]
    if missing:
        print("error: result file(s) not found:", file=sys.stderr)
        for path in missing:
            print(f"  {path}", file=sys.stderr)
        print("Run the corresponding configuration first.", file=sys.stderr)
        return 1

    figure = CcdfFigure(args.title, log_x=args.log_x)
    for run in runs:
        try:
            series = run.peak_series(args.max_time)
        except ValueError as error:
            print(f"error: {run.label}: {error}", file=sys.stderr)
            return 1
        figure.add(series)
        print(series.summary())
        if args.check_stationarity:
            for half in run.trace(args.max_time).halves(run.label):
                print(f"  {half.summary()}")
        if args.csv:
            csv_path = args.output.with_name(
                f"{args.output.stem}-{series.label.lower().replace(' ', '-')}.csv")
            series.write_csv(csv_path)
            print(f"  data: {csv_path}")

    outputs = [args.output]
    if args.also_png:
        outputs.append(args.output.with_suffix(".png"))
    for path in figure.save(*outputs):
        print(f"figure: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
