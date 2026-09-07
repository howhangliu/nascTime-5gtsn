#!/usr/bin/env python3
"""Analyze reliability, FRER behavior, and latency for the SUMO closed-loop demo."""

from __future__ import annotations

import argparse
import math
import shlex
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Histogram:
    fields: dict[str, float] = field(default_factory=dict)
    bins: list[tuple[float, int]] = field(default_factory=list)


def read_sca(path: Path) -> tuple[dict[tuple[str, str], float], dict[tuple[str, str], Histogram]]:
    scalars: dict[tuple[str, str], float] = {}
    histograms: dict[tuple[str, str], Histogram] = {}
    current: Histogram | None = None

    with path.open(encoding="utf-8") as stream:
        for raw_line in stream:
            line = raw_line.strip()
            if line.startswith("scalar "):
                fields = shlex.split(line)
                scalars[(fields[1], fields[2])] = float(fields[3])
                current = None
            elif line.startswith("statistic "):
                fields = shlex.split(line)
                current = Histogram()
                histograms[(fields[1], fields[2])] = current
            elif current is not None and line.startswith("field "):
                _, name, value = line.split(maxsplit=2)
                current.fields[name] = float(value)
            elif current is not None and line.startswith("bin\t"):
                _, boundary, count = line.split()
                current.bins.append((float(boundary), int(count)))

    return scalars, histograms


def get_scalar(values: dict[tuple[str, str], float], module: str, name: str) -> float:
    key = (module, name)
    if key not in values:
        raise KeyError(f"missing scalar {module} {name}")
    return values[key]


def count_below(histogram: Histogram, threshold: float) -> int:
    """Count samples below a threshold aligned with a histogram boundary."""
    return sum(count for lower, count in histogram.bins if lower < threshold)


def quantile_interval(histogram: Histogram, probability: float) -> tuple[float, float]:
    target = math.ceil(histogram.fields["count"] * probability)
    cumulative = 0
    finite_bins = [(lower, count) for lower, count in histogram.bins if math.isfinite(lower)]
    for index, (lower, count) in enumerate(finite_bins):
        cumulative += count
        if cumulative >= target:
            upper = finite_bins[index + 1][0] if index + 1 < len(finite_bins) else histogram.fields["max"]
            return lower, upper
    return histogram.fields["max"], histogram.fields["max"]


def percent(numerator: float, denominator: float) -> str:
    return f"{100 * numerator / denominator:.3f}%" if denominator else "n/a"


def integer(value: float) -> str:
    return f"{int(value):,}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "scalar_file",
        nargs="?",
        type=Path,
        default=Path(__file__).with_name("results") / "SumoClosedLoopUplinkFrer_run0.sca",
    )
    parser.add_argument("--vehicles", type=int, default=10)
    parser.add_argument("--deadline-ms", type=float, default=10.0)
    args = parser.parse_args()

    scalars, histograms = read_sca(args.scalar_file)
    network = "SumoClosedLoopFrerNetwork"
    rows: list[tuple[int, int, int, int, int, int]] = []

    for vehicle in range(args.vehicles):
        prefix = f"{network}.car[{vehicle}]"
        generated = get_scalar(scalars, f"{prefix}.positionSource.app[0]", "packets sent")
        primary = get_scalar(scalars, f"{prefix}.dsTt.frerReplicatorUl", "primarySent:count")
        replica = get_scalar(scalars, f"{prefix}.dsTt.frerReplicatorUl", "replicaSent:count")
        no_route = get_scalar(scalars, f"{prefix}.positionSource.ipv4.ip", "packetDropNoRouteFound:count")
        wrong_mac = get_scalar(scalars, f"{prefix}.eth[0].mac", "packetDropNotAddressedToUs:count")
        rows.append((vehicle, int(generated), int(primary), int(replica), int(no_route), int(wrong_mac)))

    generated = sum(row[1] for row in rows)
    primary = sum(row[2] for row in rows)
    replica = sum(row[3] for row in rows)
    no_route = sum(row[4] for row in rows)
    wrong_mac = sum(row[5] for row in rows)

    recovery = f"{network}.nwTt.frerRecoveryUl"
    primary_wins = get_scalar(scalars, recovery, "recoveredFromPrimary:count")
    replica_wins = get_scalar(scalars, recovery, "recoveredFromReplica:count")
    duplicates = get_scalar(scalars, recovery, "duplicatesDropped:count")
    overruns = get_scalar(scalars, recovery, "windowOverruns:count")
    received = get_scalar(scalars, f"{network}.tsnServer.app[0]", "packetReceived:count")
    payload_bytes = get_scalar(scalars, f"{network}.tsnServer.app[0]", "packetReceived:sum(packetBytes)")

    print(f"SUMO closed-loop uplink FRER analysis: {args.scalar_file}")
    print("\nAggregate reliability and FRER")
    print(f"  generated unique reports : {integer(generated)}")
    print(f"  primary / replica copies : {integer(primary)} / {integer(replica)}")
    print(f"  server unique reports    : {integer(received)} ({percent(received, generated)})")
    print(f"  unique reports missing   : {integer(max(0, generated - received))}")
    print(f"  duplicates eliminated    : {integer(duplicates)}")
    print(f"  recovery window overruns : {integer(overruns)}")
    print(f"  server payload           : {integer(payload_bytes)} bytes")
    print(f"  redundancy factor        : {(primary + replica) / generated:.2f} copies/report")
    print(f"  first copy via primary   : {integer(primary_wins)} ({percent(primary_wins, received)})")
    print(f"  first copy via replica   : {integer(replica_wins)} ({percent(replica_wins, received)})")

    histogram = histograms.get((f"{network}.tsnServer.app[0]", "endToEndDelay:histogram"))
    if histogram is not None and histogram.fields.get("count", 0):
        deadline = args.deadline_ms / 1000
        compliant = count_below(histogram, deadline)
        count = int(histogram.fields["count"])
        print(f"\nEnd-to-end delay ({count:,} received reports)")
        print(f"  mean / stddev            : {histogram.fields['mean'] * 1000:.3f} / {histogram.fields['stddev'] * 1000:.3f} ms")
        print(f"  minimum / maximum        : {histogram.fields['min'] * 1000:.3f} / {histogram.fields['max'] * 1000:.3f} ms")
        for label, probability in (("p50", 0.50), ("p95", 0.95), ("p99", 0.99)):
            lower, upper = quantile_interval(histogram, probability)
            print(f"  {label} histogram interval     : [{lower * 1000:.3f}, {upper * 1000:.3f}) ms")
        print(f"  below {args.deadline_ms:g} ms          : {compliant:,}/{count:,} ({percent(compliant, count)})")
        print(f"  at/above {args.deadline_ms:g} ms       : {count - compliant:,}/{count:,} ({percent(count - compliant, count)})")

    print("\nPer-vehicle source and replication health")
    print("  UE   generated   primary   replica   no-route   wrong-MAC   status")
    unhealthy = False
    for vehicle, sent, first, second, route_drops, mac_drops in rows:
        healthy = sent > 0 and first == sent and second == sent and route_drops == 0 and mac_drops == 0
        unhealthy |= not healthy
        print(f"  {vehicle:>2}   {sent:>9,}   {first:>7,}   {second:>7,}   {route_drops:>8,}   {mac_drops:>9,}   {'OK' if healthy else 'FAIL'}")

    invariant_failures: list[str] = []
    if received != generated:
        invariant_failures.append("server delivery does not equal generated reports")
    if primary != generated or replica != generated:
        invariant_failures.append("FRER did not create both copies for every report")
    if primary_wins + replica_wins != received:
        invariant_failures.append("FRER accepted-copy accounting does not equal server delivery")
    if duplicates != received:
        invariant_failures.append("one duplicate was not eliminated per delivered report")
    if no_route or wrong_mac or overruns or unhealthy:
        invariant_failures.append("one or more local health checks failed")

    print("\nValidation: " + ("PASS" if not invariant_failures else "FAIL"))
    for failure in invariant_failures:
        print(f"  - {failure}")
    print("Note: server delivery and delay are aggregate; current results do not record per-vehicle sink identity.")
    return 1 if invariant_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
