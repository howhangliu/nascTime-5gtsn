#!/usr/bin/env python3
"""Plot receiver Age of Information from an OMNeT++ vector file.

AoI at time t is t - u(t), where u(t) is the generation time of the newest
received update. INET's UdpSink records the end-to-end delay and application
sequence number at reception. Thus, for a packet received at r with delay d,
its generation time is u = r - d.
"""

from __future__ import annotations

import argparse
import csv
import math
import re
from dataclasses import dataclass
from pathlib import Path


VECTOR_RE = re.compile(r'^vector\s+(\d+)\s+(\S+)\s+(\S+)\s+([A-Z]+)')
SIM_LIMIT_RE = re.compile(r'^config\s+sim-time-limit\s+([0-9.eE+-]+)s\s*$')


@dataclass(frozen=True)
class Sample:
    event: int
    time: float
    value: float


def read_vectors(path: Path, module: str) -> tuple[list[Sample], list[Sample], float | None]:
    wanted = {"endToEndDelay:vector", "rcvdPkSeqNo:vector"}
    columns: dict[int, str] = {}
    samples: dict[str, list[Sample]] = {name: [] for name in wanted}
    id_to_name: dict[int, str] = {}
    sim_limit = None

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = VECTOR_RE.match(line)
            if match:
                vector_id, vector_module, name, column_spec = match.groups()
                if vector_module == module and name in wanted:
                    numeric_id = int(vector_id)
                    columns[numeric_id] = column_spec
                    id_to_name[numeric_id] = name
                continue

            match = SIM_LIMIT_RE.match(line)
            # OMNeT++ writes the selected config before inherited sections.
            # Keep the first value: a later [General] value may be present in
            # the header but is overridden by the selected configuration.
            if match and sim_limit is None:
                sim_limit = float(match.group(1))
                continue

            if not line or not line[0].isdigit():
                continue
            fields = line.split()
            try:
                vector_id = int(fields[0])
            except (ValueError, IndexError):
                continue
            column_spec = columns.get(vector_id)
            if column_spec is None:
                continue
            try:
                values = dict(zip(column_spec, fields[1:]))
                sample = Sample(int(values["E"]), float(values["T"]), float(values["V"]))
            except (KeyError, ValueError):
                raise ValueError(f"Unsupported vector row: {line.rstrip()}") from None
            name = id_to_name.get(vector_id)
            if name is not None:
                samples[name].append(sample)

    return samples["endToEndDelay:vector"], samples["rcvdPkSeqNo:vector"], sim_limit


def pair_receptions(delays: list[Sample], sequences: list[Sample]) -> list[tuple[float, float, int]]:
    delay_by_event = {sample.event: sample for sample in delays}
    seq_by_event = {sample.event: sample for sample in sequences}
    common = sorted(set(delay_by_event) & set(seq_by_event), key=lambda event: delay_by_event[event].time)
    if not common:
        raise ValueError(
            "No paired AoI samples found. Run the UplinkSinrFailoverAoI "
            "configuration and let it finish before analyzing its .vec file."
        )
    return [
        (delay_by_event[event].time, delay_by_event[event].value, round(seq_by_event[event].value))
        for event in common
    ]


def build_aoi(receptions: list[tuple[float, float, int]], end_time: float | None):
    points: list[tuple[float, float]] = []
    peaks: list[tuple[float, float, int]] = []
    latest_generation = -math.inf

    for receive_time, delay, sequence in receptions:
        generation = receive_time - delay
        if generation <= latest_generation:
            continue  # A stale/reordered update cannot make information newer.
        if latest_generation != -math.inf:
            peak = receive_time - latest_generation
            points.append((receive_time, peak))
            peaks.append((receive_time, peak, sequence))
        points.append((receive_time, receive_time - generation))
        latest_generation = generation

    if end_time is not None and points and end_time > points[-1][0]:
        points.append((end_time, end_time - latest_generation))
    return points, peaks


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vec", type=Path, help="OMNeT++ .vec result file")
    parser.add_argument("--stream", type=int, choices=(0, 1), default=0,
                        help="receiver app/UDP stream: 0=DSCP 6, 1=best effort (default: 0)")
    parser.add_argument("--output", type=Path, help="output PNG path")
    parser.add_argument("--bad-at", type=float,
                        help="mark the time when channel quality becomes bad")
    parser.add_argument("--switch-at", type=float,
                        help="mark the time when traffic switches path")
    parser.add_argument("--max-time", type=float,
                        help="override the plot/simulation end time")
    args = parser.parse_args()

    module = f"UplinkNetwork.tsnDeviceA.app[{args.stream}]"
    output = args.output or args.vec.with_name(f"{args.vec.stem}-aoi-stream{args.stream}.png")
    csv_path = output.with_suffix(".peaks.csv")

    delays, sequences, sim_limit = read_vectors(args.vec, module)
    try:
        receptions = pair_receptions(delays, sequences)
    except ValueError as error:
        raise SystemExit(f"error: {error}") from None
    end_time = args.max_time if args.max_time is not None else sim_limit
    points, peaks = build_aoi(receptions, end_time)

    try:
        import matplotlib.pyplot as plt
    except ImportError as error:
        raise SystemExit("matplotlib is required: python3 -m pip install matplotlib") from error

    x, y = zip(*points)
    # A wide canvas gives each experiment phase enough horizontal room for
    # the dense per-packet AoI sawtooth to remain visually distinguishable.
    fig, ax = plt.subplots(figsize=(16, 5.5))
    ax.plot(x, [value * 1000 for value in y], color="tab:blue", linewidth=1.0, label="AoI")
    plot_end = end_time or x[-1]
    if args.bad_at is not None:
        bad_end = args.switch_at if args.switch_at is not None else plot_end
        ax.axvspan(args.bad_at, bad_end, color="tab:red", alpha=0.10,
                   label="degraded active path")
        ax.axvline(args.bad_at, color="tab:red", linestyle="--", linewidth=1)
    if args.switch_at is not None:
        ax.axvspan(args.switch_at, plot_end, color="tab:green", alpha=0.08,
                   label="traffic on standby path")
        ax.axvline(args.switch_at, color="tab:green", linestyle="--", linewidth=1)
    ax.set(title=f"Age of Information — {args.vec.stem}, stream {args.stream}",
           xlabel="Simulation time (s)", ylabel="Age of Information (ms)")
    ax.set_xlim(0, plot_end)
    ax.set_ylim(bottom=0)
    ax.margins(x=0)
    ax.grid(True, alpha=0.25)
    ax.legend()
    fig.tight_layout()
    fig.savefig(output, dpi=180)

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["simulation_time_s", "peak_aoi_s", "peak_aoi_ms", "received_sequence"])
        writer.writerows((time, peak, peak * 1000, sequence) for time, peak, sequence in peaks)

    peak_values = [peak for _, peak, _ in peaks]
    print(f"Received updates: {len(receptions)}")
    print(f"AoI peaks: {len(peaks)}")
    if peak_values:
        print(f"Mean peak AoI: {sum(peak_values) / len(peak_values) * 1000:.3f} ms")
        print(f"Maximum peak AoI: {max(peak_values) * 1000:.3f} ms")
    print(f"Plot: {output}")
    print(f"Peak data: {csv_path}")


if __name__ == "__main__":
    main()
