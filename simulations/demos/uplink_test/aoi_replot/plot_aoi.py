#!/usr/bin/env python3
"""Replot the UplinkSinrFailoverAoI Age-of-Information timeline.

Standalone: matplotlib is the only dependency, and nothing here imports from
the rest of the repository. It reads either the pre-extracted CSV (fast, the
default) or the raw OMNeT++ ``.vec`` file, so the figure can be regenerated
after a fresh simulation run without touching this script.

    python3 plot_aoi.py                       # the AoI sawtooth (default)
    python3 plot_aoi.py --mode paoi           # peak AoI against simulation time
    python3 plot_aoi.py --mode both           # the sawtooth with its peaks marked
    python3 plot_aoi.py --mode paoi --window 50   # add a 50-sample trend line
    python3 plot_aoi.py --stream 1            # the best-effort stream
    python3 plot_aoi.py --from-vec            # re-derive everything from the .vec

Everything worth adjusting for a paper figure -- size, colours, phase
boundaries, axis limits -- is in the STYLE block below.
"""

from __future__ import annotations

import argparse
import csv
import math
import re
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # Render to a file; never open a window.
import matplotlib.pyplot as plt  # noqa: E402  (must follow the backend choice)


HERE = Path(__file__).resolve().parent
DATA = HERE / "data"

# --------------------------------------------------------------------------
# STYLE -- change these to restyle the figure.
# --------------------------------------------------------------------------
FIGSIZE = (16.0, 5.5)       # inches; wide so the 1 ms sawtooth stays readable
DPI = 180
LINE_COLOR = "#2a78d6"      # the AoI curve
LINE_WIDTH = 1.0
BAD_COLOR = "#e34948"       # degraded-active-path band (red)
SWITCH_COLOR = "#008300"    # standby-path band (green)
BAND_ALPHA = 0.10
PEAK_COLOR = "#eb6834"      # the PAoI markers, in --mode paoi and --mode both
PEAK_MARKER = "."
PEAK_MARKERSIZE = 3.0
TREND_COLOR = "#4a3aa7"     # the --window trend line
TEXT_PRIMARY = "#0b0b0b"
TEXT_SECONDARY = "#52514e"

# Scenario phase boundaries, in seconds. Set either to None to drop that band.
BAD_AT = 1.0                # UE 0 takes a 12 dB uplink SINR penalty
SWITCH_AT = 2.0             # traffic moves to the healthy standby leg
END_TIME = 3.0              # sim-time-limit

Y_MAX = None                # e.g. 60 to pin the y-axis; None = autoscale

plt.rcParams.update({
    "pdf.fonttype": 42,     # embed real TrueType, so text stays selectable
    "ps.fonttype": 42,
    "font.size": 10,
    "axes.edgecolor": TEXT_SECONDARY,
    "axes.labelcolor": TEXT_PRIMARY,
    "text.color": TEXT_PRIMARY,
    "xtick.color": TEXT_SECONDARY,
    "ytick.color": TEXT_SECONDARY,
})


# --------------------------------------------------------------------------
# Reading the pre-extracted CSV
# --------------------------------------------------------------------------
def read_timeline(path: Path) -> tuple[list[float], list[float]]:
    """The plotted sample path itself: (times in s, AoI in ms)."""
    times, values = [], []
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            times.append(float(row["time_s"]))
            values.append(float(row["aoi_ms"]))
    return times, values


def read_peaks(path: Path) -> tuple[list[float], list[float]]:
    times, values = [], []
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            times.append(float(row["time_s"]))
            values.append(float(row["peak_aoi_ms"]))
    return times, values


# --------------------------------------------------------------------------
# Deriving AoI straight from an OMNeT++ .vec file
# --------------------------------------------------------------------------
VECTOR_RE = re.compile(r"^vector\s+(\d+)\s+(\S+)\s+(\S+)\s+([A-Z]+)")


def read_vectors(path: Path, module: str, names: list[str]) -> dict[str, dict[int, tuple[float, float]]]:
    """Pull `names` for one module, keyed by the event id that recorded them.

    OMNeT++ writes a declaration line per vector (id, module, name, column
    layout) followed by rows whose first field is that id. The column layout
    string says which field is the Event, the Time and the Value.
    """
    wanted = {f"{name}:vector" for name in names}
    layout: dict[int, str] = {}
    id_to_name: dict[int, str] = {}
    samples: dict[str, dict[int, tuple[float, float]]] = {name: {} for name in wanted}

    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = VECTOR_RE.match(line)
            if match:
                vector_id, vector_module, name, columns = match.groups()
                if vector_module == module and name in wanted:
                    layout[int(vector_id)] = columns
                    id_to_name[int(vector_id)] = name
                continue
            if not line or not line[0].isdigit():
                continue
            fields = line.split()
            columns = layout.get(int(fields[0]))
            if columns is None:
                continue
            values = dict(zip(columns, fields[1:]))
            samples[id_to_name[int(fields[0])]][int(values["E"])] = (
                float(values["T"]), float(values["V"]))

    missing = [name for name in wanted if not samples[name]]
    if missing:
        raise SystemExit(f"error: {path} has no {', '.join(missing)} for '{module}'")
    return {name.removesuffix(":vector"): value for name, value in samples.items()}


def aoi_from_vec(path: Path, module: str, end_time: float | None):
    """Reconstruct the AoI sawtooth and its peaks from a run's raw vectors.

    A packet received at r with end-to-end delay d was generated at r - d, so
    AoI drops to d on arrival and then climbs at 45 degrees. A stale or
    reordered packet carries no newer information, so it is skipped and widens
    the following peak instead of producing one of its own.
    """
    recorded = read_vectors(path, module, ["endToEndDelay", "rcvdPkSeqNo"])
    delays, sequences = recorded["endToEndDelay"], recorded["rcvdPkSeqNo"]
    events = sorted(set(delays) & set(sequences), key=lambda event: delays[event][0])

    points: list[tuple[float, float]] = []
    peaks: list[tuple[float, float]] = []
    latest_generation = -math.inf
    for event in events:
        time, delay = delays[event]
        generation = time - delay
        if generation <= latest_generation:
            continue
        if latest_generation != -math.inf:
            peak = time - latest_generation
            points.append((time, peak))
            peaks.append((time, peak))
        points.append((time, delay))
        latest_generation = generation

    if end_time is not None and points and end_time > points[-1][0]:
        points.append((end_time, end_time - latest_generation))

    times = [time for time, _ in points]
    values = [value * 1000 for _, value in points]
    peak_times = [time for time, _ in peaks]
    peak_values = [value * 1000 for _, value in peaks]
    return times, values, peak_times, peak_values


# --------------------------------------------------------------------------
def moving_average(times: list[float], values: list[float], window: int):
    """Centred running mean over `window` consecutive PAoI samples.

    PAoI is one sample per reception, not a signal on a regular grid, so the
    window counts samples rather than seconds. At ~1000 receptions per second
    a window of 50 smooths over roughly 50 ms.
    """
    if window < 2 or len(values) < window:
        return [], []
    half = window // 2
    running = sum(values[:window])
    smoothed_times = [times[half]]
    smoothed_values = [running / window]
    for i in range(window, len(values)):
        running += values[i] - values[i - window]
        smoothed_times.append(times[i - half])
        smoothed_values.append(running / window)
    return smoothed_times, smoothed_values


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--stream", type=int, default=0,
                        help="0 = periodic DSCP 6 updates, 1 = best effort (default: 0)")
    parser.add_argument("--from-vec", action="store_true",
                        help="re-derive AoI from the .vec instead of reading the CSV")
    parser.add_argument("--vec", type=Path, default=DATA / "UplinkSinrFailoverAoI-#0.vec",
                        help="raw OMNeT++ vector file, for --from-vec")
    parser.add_argument("--receiver", default="UplinkNetwork.tsnDeviceA",
                        help="receiving module path, for --from-vec")
    parser.add_argument("--mode", choices=("aoi", "paoi", "both"), default="aoi",
                        help="aoi: the sawtooth (default); paoi: peak AoI against "
                             "simulation time; both: the sawtooth with peaks marked")
    parser.add_argument("--window", type=int, default=0, metavar="N",
                        help="in --mode paoi, overlay a running mean over N samples "
                             "(default: 0, no trend line)")
    parser.add_argument("--title", default=None, help="override the figure title")
    parser.add_argument("--output", type=Path, default=None,
                        help="output path; the suffix picks the format (.png, .pdf, .svg)")
    args = parser.parse_args()

    if args.from_vec:
        module = f"{args.receiver}.app[{args.stream}]"
        times, values, peak_times, peak_values = aoi_from_vec(args.vec, module, END_TIME)
    else:
        times, values = read_timeline(DATA / f"aoi_timeline_stream{args.stream}.csv")
        peak_times, peak_values = read_peaks(DATA / f"peaks_stream{args.stream}.csv")

    quantity = "Peak Age of Information" if args.mode == "paoi" else "Age of Information"
    label = "paoi" if args.mode == "paoi" else "aoi"
    title = args.title or f"{quantity} — UplinkSinrFailoverAoI-#0, stream {args.stream}"
    output = args.output or HERE / f"UplinkSinrFailoverAoI-#0-{label}-stream{args.stream}.png"

    figure, axes = plt.subplots(figsize=FIGSIZE)
    axes.set_title(title, color=TEXT_PRIMARY)
    axes.set(xlabel="Simulation time (s)", ylabel=f"{quantity} (ms)")
    axes.grid(True, alpha=0.25)
    axes.set_axisbelow(True)

    if args.mode in ("aoi", "both"):
        axes.plot(times, values, color=LINE_COLOR, linewidth=LINE_WIDTH, label="AoI")

    if args.mode in ("paoi", "both"):
        # PAoI is a sequence of samples dated by the reception that ended each
        # ramp, so it is drawn as points: joining them would imply a value
        # between receptions, where peak AoI is simply not defined.
        axes.plot(peak_times, peak_values, linestyle="none", marker=PEAK_MARKER,
                  markersize=PEAK_MARKERSIZE, color=PEAK_COLOR, label="peak AoI")

    if args.mode == "paoi" and args.window:
        trend_times, trend_values = moving_average(peak_times, peak_values, args.window)
        if trend_times:
            axes.plot(trend_times, trend_values, color=TREND_COLOR, linewidth=1.8,
                      label=f"running mean ({args.window} samples)")

    # Bands are drawn after the curve so their labels land last in the legend.
    if BAD_AT is not None:
        bad_end = SWITCH_AT if SWITCH_AT is not None else END_TIME
        axes.axvspan(BAD_AT, bad_end, color=BAD_COLOR, alpha=BAND_ALPHA,
                     label="degraded active path")
        axes.axvline(BAD_AT, color=BAD_COLOR, linestyle="--", linewidth=1)
    if SWITCH_AT is not None:
        axes.axvspan(SWITCH_AT, END_TIME, color=SWITCH_COLOR, alpha=BAND_ALPHA,
                     label="traffic on standby path")
        axes.axvline(SWITCH_AT, color=SWITCH_COLOR, linestyle="--", linewidth=1)

    axes.set_xlim(0, END_TIME)
    axes.set_ylim(bottom=0, top=Y_MAX)
    axes.margins(x=0)
    axes.legend(frameon=False)

    figure.tight_layout()
    figure.savefig(output, dpi=DPI)
    plt.close(figure)

    mean = sum(peak_values) / len(peak_values)
    print(f"AoI samples: {len(times)}   peaks: {len(peak_values)}")
    print(f"Peak AoI: mean={mean:.3f} ms   max={max(peak_values):.3f} ms")

    # Per-phase peak AoI: the whole point of the scenario is the contrast.
    for start, end, phase in ((0.0, BAD_AT, "baseline"),
                              (BAD_AT, SWITCH_AT, "degraded"),
                              (SWITCH_AT, END_TIME, "standby")):
        if start is None or end is None:
            continue
        window = [value for time, value in zip(peak_times, peak_values)
                  if start <= time < end]
        if window:
            print(f"  {phase:9s} {start:g}-{end:g}s: n={len(window):5d} "
                  f"mean={sum(window) / len(window):6.2f} ms   max={max(window):6.2f} ms")

    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
