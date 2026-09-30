#!/usr/bin/env python3
"""Plot age of information from a named scenario, or from raw result files.

The figures this project publishes are registered in ``paoi/scenarios.py``, so
regenerating one takes only its name::

    plot_aoi.py --scenario 5g-tsn
    plot_aoi.py --all

Each scenario has a default mode, which ``--mode`` overrides:

    ccdf        the peak-AoI distribution, one curve per run
    timeline    the AoI sawtooth against simulation time
    peaks       peak AoI against simulation time, one marker per reception
    both        the sawtooth with its peaks marked

A registered scenario reads its raw ``.vec`` when one is present and falls back
to the committed dataset otherwise, so a fresh clone can redraw every figure
without the multi-megabyte result files. After re-running a simulation,
``--export`` refreshes those datasets from the new results.

For anything not registered, describe the curves directly. Each ``--run`` adds
one, given as ``label=path/to/run.vec``; the receiving application module is
shared by every run in a figure::

    plot_aoi.py --module TasComparisonNetwork.tsnDeviceB.app[0] \\
        --run "Baseline=results/baseline/Baseline-#0.vec" \\
        --run "TAS=results/tas/Tas-#0.vec" \\
        --output figures/paoi-ccdf.pdf
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from paoi import (AoiTimelineFigure, CcdfFigure, RunSpec, SCENARIOS,  # noqa: E402
                  Scenario, figure_path)

MODES = ("ccdf", "timeline", "peaks", "both")


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
    parser.add_argument("--mode", choices=MODES,
                        help="which figure to draw (default: the scenario's own)")
    parser.add_argument("--only", action="append", metavar="TEXT",
                        help="keep only runs whose label contains TEXT; repeatable")
    parser.add_argument("--window", type=int, default=0, metavar="N",
                        help="in --mode peaks, overlay a running mean over N samples")
    parser.add_argument("--export", action="store_true",
                        help="extract each run's receptions from its .vec into "
                             "the committed dataset, instead of plotting")
    parser.add_argument("--module",
                        help="full path of the receiving application module "
                             "(required with --run)")
    parser.add_argument("--output", type=Path,
                        help="output figure path; the suffix picks the format "
                             "(required with --run)")
    parser.add_argument("--no-png", action="store_true",
                        help="write only the requested format, not a PNG alongside")
    parser.add_argument("--title", help="override the figure title")
    parser.add_argument("--log-x", action="store_true", help="logarithmic x axis, in --mode ccdf")
    parser.add_argument("--max-time", type=float,
                        help="override the run's own end time when closing the trace")
    parser.add_argument("--csv", action="store_true",
                        help="write per-curve CCDF data beside the figure")
    parser.add_argument("--check-stationarity", action="store_true",
                        help="also report each run's two halves, to show whether "
                             "the queue reached steady state")
    return parser


def report(scenario: Scenario, run: RunSpec, trace, args) -> None:
    """Print what a run measured, per phase when the scenario has phases."""
    print(f"  {trace.peak_series(run.label).summary()}")
    if args.check_stationarity:
        for half in trace.halves(run.label):
            print(f"    {half.summary()}")
    for phase in scenario.phases:
        series = trace.peak_series(phase.label, start=phase.start, end=phase.end)
        print(f"    {phase.start:g}-{phase.end:g}s {series.summary()}")


def draw_ccdf(scenario: Scenario, output: Path, args) -> None:
    figure = CcdfFigure(args.title or scenario.title, log_x=args.log_x)
    for run in scenario.runs:
        trace = run.trace(args.max_time)
        figure.add(trace.peak_series(run.label))
        report(scenario, run, trace, args)
        if args.csv:
            csv_path = output.with_name(
                f"{output.stem}-{run.label.lower().replace(' ', '-')}.csv")
            trace.peak_series(run.label).write_csv(csv_path)
            print(f"  data: {csv_path}")
    return figure


def draw_timeline(scenario: Scenario, output: Path, args) -> None:
    quantity = "Peak Age of Information" if args.mode == "peaks" else "Age of Information"
    figure = AoiTimelineFigure(args.title or scenario.title, ylabel=f"{quantity} (ms)")
    end_time = args.max_time or scenario.end_time
    for run in scenario.runs:
        trace = run.trace(args.max_time)
        if args.mode in ("timeline", "both"):
            figure.add(trace, label=f"AoI — {run.label}")
        if args.mode in ("peaks", "both"):
            figure.add_peaks(trace, label=f"peak AoI — {run.label}")
        if args.mode == "peaks" and args.window:
            figure.add_trend(trace, args.window,
                             label=f"running mean, {args.window} samples — {run.label}")
        report(scenario, run, trace, args)
        end_time = end_time or trace.end_time
    # Bands go on after the curves so their labels land last in the legend.
    for phase in scenario.phases:
        if phase.shade:
            figure.mark_span(phase.start, phase.end, phase.label, phase.color)
    figure.finish(end_time)
    return figure


def plot(scenario: Scenario, output: Path, args) -> int:
    """Render one figure; return a shell exit status."""
    missing = scenario.missing()
    if missing:
        print(f"error: {scenario.name}: no data for "
              f"{', '.join(run.label for run in missing)}.", file=sys.stderr)
        print("Each run needs either raw results or a committed dataset:", file=sys.stderr)
        for run in missing:
            print(f"  {run.vec}", file=sys.stderr)
            print(f"  {run.dataset}", file=sys.stderr)
        print("Run the corresponding configuration, or check out the dataset.",
              file=sys.stderr)
        return 1

    print(scenario.title)
    try:
        draw = draw_ccdf if args.mode == "ccdf" else draw_timeline
        figure = draw(scenario, output, args)
    except (ValueError, FileNotFoundError) as error:
        print(f"error: {scenario.name}: {error}", file=sys.stderr)
        return 1

    outputs = [output]
    if not args.no_png:
        outputs.append(output.with_suffix(".png"))
    for path in figure.save(*outputs):
        print(f"  figure: {path}")
    return 0


def export(scenario: Scenario) -> int:
    """Refresh a scenario's committed datasets from its raw results."""
    print(scenario.title)
    status = 0
    for run in scenario.runs:
        try:
            path = run.export()
        except (FileNotFoundError, ValueError) as error:
            print(f"error: {error}", file=sys.stderr)
            status = 1
            continue
        print(f"  {run.label}: {path} ({path.stat().st_size / 1024:.0f} KiB)")
    return status


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.run:
        if args.export:
            parser.error("--export works on registered scenarios, not --run")
        if not args.module or not args.output:
            parser.error("--run needs both --module and --output")
        args.mode = args.mode or "ccdf"
        scenario = Scenario(name="custom", title=args.title or "Peak age of information",
                            runs=tuple(parse_run(text, args.module) for text in args.run))
        return plot(scenario, args.output, args)

    requested_mode = args.mode
    names = sorted(SCENARIOS) if args.all else [args.scenario]
    status = 0
    for name in names:
        try:
            scenario = SCENARIOS[name].select(args.only)
        except ValueError as error:
            print(f"error: {error}", file=sys.stderr)
            status = 1
            continue
        if args.export:
            status |= export(scenario)
            continue
        # Each scenario falls back to its own default, so --all draws the right
        # figure for every one of them without naming a mode.
        args.mode = requested_mode or scenario.default_mode
        output = (args.output if args.output and not args.all
                  else figure_path(scenario, args.mode))
        status |= plot(scenario, output, args)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
