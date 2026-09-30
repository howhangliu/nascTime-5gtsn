"""Age of Information reconstructed from a receiver's update stream.

AoI at time t is t - u(t), where u(t) is the generation time of the newest
received update. INET's UdpSink records the end-to-end delay and application
sequence number at reception, so for a packet received at r with delay d its
generation time is u = r - d.

Peak AoI is the value the sawtooth reaches immediately before each reception
that refreshes the receiver's knowledge: for reception n, r_n - u_{n-1}. A lost
or reordered update never lowers the age, so it widens the following peak
instead of producing one of its own.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Reception:
    """One delivered update, as seen at the receiving application."""

    time: float
    delay: float
    sequence: int

    @property
    def generation(self) -> float:
        return self.time - self.delay


@dataclass(frozen=True)
class PeakSample:
    """A peak of the AoI sawtooth, dated by the reception that ended it."""

    time: float
    value: float
    sequence: int


class AoiTrace:
    """The AoI sample path of one receiver stream."""

    def __init__(self, receptions: list[Reception], end_time: float | None = None):
        if not receptions:
            raise ValueError("an AoI trace needs at least one reception")
        self.receptions = receptions
        self.end_time = end_time
        self.points: list[tuple[float, float]] = []
        self.peaks: list[PeakSample] = []
        self._build()

    @classmethod
    def from_vector_file(cls, vectors, module: str, end_time: float | None = None) -> "AoiTrace":
        """Build a trace from `module`'s delay and sequence-number vectors.

        `vectors` is a :class:`~paoi.vectors.VectorFile`. When `end_time` is
        None the run's own ``sim-time-limit`` closes the final sawtooth ramp.
        """
        recorded = vectors.read(module, ["endToEndDelay", "rcvdPkSeqNo"])
        delays = recorded["endToEndDelay"]
        sequences = recorded["rcvdPkSeqNo"]
        if not delays or not sequences:
            known = sorted(set(vectors.modules_with("endToEndDelay")))
            raise ValueError(
                f"no endToEndDelay/rcvdPkSeqNo vector pair for '{module}' in {vectors.path}."
                + (f" Modules that recorded endToEndDelay: {', '.join(known)}" if known else
                   " The file records no endToEndDelay at all -- check that the run"
                   " enabled vector recording on the receiving application.")
            )
        if end_time is None:
            end_time = vectors.sim_time_limit
        return cls(cls._pair(delays, sequences), end_time)

    @staticmethod
    def _pair(delays, sequences) -> list[Reception]:
        """Join the two vectors on the reception event that wrote both."""
        delay_by_event = {sample.event: sample for sample in delays}
        seq_by_event = {sample.event: sample for sample in sequences}
        common = sorted(set(delay_by_event) & set(seq_by_event),
                        key=lambda event: delay_by_event[event].time)
        if not common:
            raise ValueError("endToEndDelay and rcvdPkSeqNo share no reception events")
        return [
            Reception(delay_by_event[event].time,
                      delay_by_event[event].value,
                      round(seq_by_event[event].value))
            for event in common
        ]

    def _build(self) -> None:
        latest_generation = -math.inf
        for reception in self.receptions:
            generation = reception.generation
            if generation <= latest_generation:
                continue  # A stale/reordered update cannot make information newer.
            if latest_generation != -math.inf:
                peak = reception.time - latest_generation
                self.points.append((reception.time, peak))
                self.peaks.append(PeakSample(reception.time, peak, reception.sequence))
            self.points.append((reception.time, reception.delay))
            latest_generation = generation

        if self.end_time is not None and self.points and self.end_time > self.points[-1][0]:
            self.points.append((self.end_time, self.end_time - latest_generation))

    def peak_series(self, label: str, start: float | None = None,
                    end: float | None = None) -> "PeakAoiSeries":
        """Peak AoI over the whole trace, or over the window [start, end)."""
        return PeakAoiSeries(label, [
            peak.value for peak in self.peaks
            if (start is None or peak.time >= start) and (end is None or peak.time < end)
        ])

    def halves(self, label: str) -> tuple["PeakAoiSeries", "PeakAoiSeries"]:
        """The trace split at the midpoint of its recorded window.

        A stationary queue gives two halves with the same distribution. If the
        second half is visibly worse, the link is overloaded and the backlog is
        still growing -- the quantiles then describe the run length rather than
        the system, and the load has to come down before a CCDF means anything.
        """
        first, last = self.peaks[0].time, self.peaks[-1].time
        midpoint = first + (last - first) / 2
        return (self.peak_series(f"{label} (1st half)", end=midpoint),
                self.peak_series(f"{label} (2nd half)", start=midpoint))


class PeakAoiSeries:
    """The peak-AoI values of one run, as a distribution rather than a signal."""

    def __init__(self, label: str, values: list[float]):
        if not values:
            raise ValueError(f"series '{label}' has no peak AoI samples")
        self.label = label
        self.values = sorted(values)

    def __len__(self) -> int:
        return len(self.values)

    def ccdf(self) -> tuple[list[float], list[float]]:
        """Empirical complementary CDF as (x, y) with y = P(PAoI >= x).

        The i-th of n sorted samples carries probability (n - i + 1) / n, so
        the curve starts at 1 and ends at 1/n -- every point stays plottable on
        a logarithmic axis, and 1/n reads off directly as the resolution floor.
        """
        count = len(self.values)
        return list(self.values), [(count - i) / count for i in range(count)]

    @property
    def mean(self) -> float:
        return sum(self.values) / len(self.values)

    @property
    def maximum(self) -> float:
        return self.values[-1]

    def quantile(self, probability: float) -> float:
        """The smallest sample at or above `probability` of the distribution."""
        if not 0 < probability <= 1:
            raise ValueError("quantile probability must be in (0, 1]")
        index = math.ceil(probability * len(self.values)) - 1
        return self.values[index]

    def summary(self) -> str:
        return (f"{self.label}: n={len(self)} "
                f"mean={self.mean * 1000:.3f} ms "
                f"p99={self.quantile(0.99) * 1000:.3f} ms "
                f"max={self.maximum * 1000:.3f} ms")

    def write_csv(self, path: Path) -> None:
        import csv

        with Path(path).open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(["peak_aoi_s", "peak_aoi_ms", "ccdf"])
            writer.writerows((x, x * 1000, y) for x, y in zip(*self.ccdf()))
