"""Naming one measured stream, so scripts can describe a figure declaratively."""

from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path

from .aoi import AoiTrace, PeakAoiSeries
from .dataset import read_receptions, write_receptions
from .vectors import VectorFile


@dataclass(frozen=True)
class Phase:
    """A labelled stretch of a run: what was happening, and how to shade it.

    Phases are what makes an event-driven scenario readable -- the figure
    bands them, and the per-phase peak-AoI statistics are the contrast the
    scenario exists to show.
    """

    start: float
    end: float
    label: str
    color: str
    #: Whether to shade this phase on a timeline. The stretch a scenario
    #: starts from is the reference, not an event, so it reads better
    #: unshaded -- and a band cannot then be mistaken for a curve.
    shade: bool = True


@dataclass(frozen=True)
class RunSpec:
    """One curve: which result file, which receiving application, what to call it.

    A run has two possible sources. ``vec`` is the raw OMNeT++ output, which is
    large and untracked; ``dataset`` is the committed extract of the receptions
    that ``vec``'s figure was drawn from. Whoever has just run the simulation
    reads the ``.vec``; whoever only cloned the repository reads the dataset,
    and gets the same numbers either way.
    """

    vec: Path
    module: str
    label: str
    dataset: Path | None = None

    def source(self) -> Path | None:
        """The file this run can actually be read from, if either exists."""
        for candidate in (self.vec, self.dataset):
            if candidate is not None and Path(candidate).exists():
                return Path(candidate)
        return None

    def trace(self, end_time: float | None = None) -> AoiTrace:
        source = self.source()
        if source is None:
            raise FileNotFoundError(
                f"{self.label}: neither {self.vec} nor {self.dataset} exists")
        if source.suffix == ".vec":
            return AoiTrace.from_vector_file(VectorFile(source), self.module, end_time)
        receptions, recorded_end = read_receptions(source)
        return AoiTrace(receptions, recorded_end if end_time is None else end_time)

    def peak_series(self, end_time: float | None = None) -> PeakAoiSeries:
        return self.trace(end_time).peak_series(self.label)

    def export(self) -> Path:
        """Extract this run's receptions from its ``.vec`` into its dataset."""
        if self.dataset is None:
            raise ValueError(f"{self.label} has no dataset path to export to")
        vec = Path(self.vec)
        if not vec.exists():
            raise FileNotFoundError(f"{self.label}: {vec} does not exist")
        vectors = VectorFile(vec)
        trace = AoiTrace.from_vector_file(vectors, self.module)
        return write_receptions(self.dataset, trace.receptions, module=self.module,
                                end_time=trace.end_time, source=vec.name)


@dataclass(frozen=True)
class Scenario:
    """A figure's worth of runs: the curves that belong on one set of axes."""

    name: str
    title: str
    runs: tuple[RunSpec, ...]
    phases: tuple[Phase, ...] = ()
    #: The figure this scenario publishes when --mode is not given.
    default_mode: str = "ccdf"
    #: Where the run ends, for scenarios whose figure needs an x limit.
    end_time: float | None = None

    def select(self, patterns: list[str] | None) -> "Scenario":
        """The same scenario narrowed to runs whose label matches a pattern."""
        if not patterns:
            return self
        lowered = [pattern.lower() for pattern in patterns]
        kept = tuple(run for run in self.runs
                     if any(pattern in run.label.lower() for pattern in lowered))
        if not kept:
            raise ValueError(
                f"no run in '{self.name}' matches {patterns}; "
                f"it has: {', '.join(run.label for run in self.runs)}")
        return replace(self, runs=kept)

    def peak_series(self, end_time: float | None = None) -> list[PeakAoiSeries]:
        return [run.peak_series(end_time) for run in self.runs]

    def missing(self) -> list[RunSpec]:
        """The runs that have neither raw results nor a committed dataset."""
        return [run for run in self.runs if run.source() is None]
