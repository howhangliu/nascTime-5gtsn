"""Naming one measured stream, so scripts can describe a figure declaratively."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .aoi import AoiTrace, PeakAoiSeries
from .vectors import VectorFile


@dataclass(frozen=True)
class RunSpec:
    """One curve: which result file, which receiving application, what to call it."""

    vec: Path
    module: str
    label: str

    def trace(self, end_time: float | None = None) -> AoiTrace:
        return AoiTrace.from_vector_file(VectorFile(self.vec), self.module, end_time)

    def peak_series(self, end_time: float | None = None) -> PeakAoiSeries:
        return self.trace(end_time).peak_series(self.label)


@dataclass(frozen=True)
class Scenario:
    """A figure's worth of runs: the curves that belong on one set of axes."""

    name: str
    title: str
    runs: tuple[RunSpec, ...]

    def peak_series(self, end_time: float | None = None) -> list[PeakAoiSeries]:
        return [run.peak_series(end_time) for run in self.runs]

    def missing(self) -> list[Path]:
        return [run.vec for run in self.runs if not Path(run.vec).exists()]
