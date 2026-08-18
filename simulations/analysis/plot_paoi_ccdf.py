#!/usr/bin/env python3
"""Plot a peak-AoI CCDF, either from a named scenario or from raw result files.

The figures this project publishes are registered in ``paoi/scenarios.py``, so
regenerating one takes only its name::

    plot_paoi_ccdf.py --scenario 5g-tsn
    plot_paoi_ccdf.py --all

For anything not registered, describe the curves directly. Each ``--run`` adds
one, given as ``label=path/to/run.vec``; the receiving application module is
shared by every run in a figure::

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

from paoi import CcdfFigure, RunSpec, SCENARIOS, Scenario, figure_path  # noqa: E402


def parse_run(text: str, module: str) -> RunSpec:
    label, separator, path = text.partition("=")
    if not separator:
        raise argparse.ArgumentTypeError(f"--run needs 'label=path', got '{text}'")
    return RunSpec(vec=Path(path), module=module, label=label)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--scenario", choices=sorted(SCENARIOS),
                        help="regenerate one registered figure")
    source.add_argument("--all", action="store_true",
                        help="regenerate every registered figure")
    source.add_argument("--run", action="append", metavar="LABEL=VEC",
                        help="one curve; repeat for each configuration to compare")
    parser.add_argument("--module",
                        help="full path of the receiving application module "
                             "(required with --run)")
    parser.add_argument("--output", type=Path,
                        help="output figure path; the suffix picks the format "
                             "(required with --run)")
    parser.add_argument("--no-png", action="store_true",
                        help="write only the requested format, not a PNG alongside")
    parser.add_argument("--title", help="override the figure title")
    parser.add_argument("--log-x", action="store_true", help="logarithmic x axis")
    parser.add_argument("--max-time", type=float,
                        help="override the run's own end time when closing the trace")
    parser.add_argument("--csv", action="store_true",
                        help="write per-curve CCDF data beside the figure")
    parser.add_argument("--check-stationarity", action="store_true",
                        help="also report each run's two halves, to show whether "
                             "the queue reached steady state")
    return parser


def plot(scenario: Scenario, output: Path, args) -> int:
    """Render one figure; return a shell exit status."""
    missing = scenario.missing()
    if missing:
        print(f"error: {scenario.name}: result file(s) not found:", file=sys.stderr)
        for path in missing:
            print(f"  {path}", file=sys.stderr)
        print("Run the corresponding configuration first.", file=sys.stderr)
        return 1

    print(f"{scenario.title}")
    figure = CcdfFigure(args.title or scenario.title, log_x=args.log_x)
    for run in scenario.runs:
        try:
            series = run.peak_series(args.max_time)
        except ValueError as error:
            print(f"error: {run.label}: {error}", file=sys.stderr)
            return 1
        figure.add(series)
        print(f"  {series.summary()}")
        if args.check_stationarity:
            for half in run.trace(args.max_time).halves(run.label):
                print(f"    {half.summary()}")
        if args.csv:
            csv_path = output.with_name(
                f"{output.stem}-{series.label.lower().replace(' ', '-')}.csv")
            series.write_csv(csv_path)
            print(f"  data: {csv_path}")

    outputs = [output]
    if not args.no_png:
        outputs.append(output.with_suffix(".png"))
    for path in figure.save(*outputs):
        print(f"  figure: {path}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.run:
        if not args.module or not args.output:
            parser.error("--run needs both --module and --output")
        scenario = Scenario(name="custom", title=args.title or "Peak age of information",
                            runs=tuple(parse_run(text, args.module) for text in args.run))
        return plot(scenario, args.output, args)

    names = sorted(SCENARIOS) if args.all else [args.scenario]
    status = 0
    for name in names:
        scenario = SCENARIOS[name]
        output = args.output if args.output and not args.all else figure_path(scenario)
        status |= plot(scenario, output, args)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
