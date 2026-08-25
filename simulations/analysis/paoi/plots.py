"""Figures built from :mod:`paoi.aoi` series.

Every figure class follows the same shape: construct it, ``add`` one series per
curve, then ``save`` to one or more paths. The file suffix picks the format, so
the same figure can go to PDF for a paper and PNG for a quick look.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # These scripts render files; they never open a window.
import matplotlib.pyplot as plt  # noqa: E402  (must follow the backend choice)


# Categorical slots 1-8 in fixed order. Curves take slots in the order they are
# added, so a series keeps its colour no matter how many others are on the axes.
SERIES_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100",
                 "#e87ba4", "#008300", "#4a3aa7", "#e34948"]

TEXT_PRIMARY = "#0b0b0b"
TEXT_SECONDARY = "#52514e"

# Slots reserved for the two extra marks a timeline can carry, so they never
# collide with the curve colours a scenario's runs take from SERIES_COLORS.
PEAK_COLOR = "#eb6834"
TREND_COLOR = "#4a3aa7"

# Papers want selectable text, not outlines: type 42 embeds real TrueType.
plt.rcParams.update({
    "pdf.fonttype": 42,
    "ps.fonttype": 42,
    "font.size": 10,
    "axes.edgecolor": TEXT_SECONDARY,
    "axes.labelcolor": TEXT_PRIMARY,
    "text.color": TEXT_PRIMARY,
    "xtick.color": TEXT_SECONDARY,
    "ytick.color": TEXT_SECONDARY,
})


def moving_average(times: list[float], values: list[float], window: int):
    """Centred running mean over `window` consecutive samples.

    Peak AoI is one sample per reception, not a signal on a regular grid, so
    the window counts samples rather than seconds. At ~1000 receptions per
    second a window of 50 smooths over roughly 50 ms.
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


class Figure:
    """Shared plumbing: a single axes, a colour sequence, and saving."""

    def __init__(self, title: str, figsize: tuple[float, float]):
        self.figure, self.axes = plt.subplots(figsize=figsize)
        self.axes.set_title(title, color=TEXT_PRIMARY)
        self._series_count = 0

    def _next_color(self) -> str:
        color = SERIES_COLORS[self._series_count % len(SERIES_COLORS)]
        self._series_count += 1
        return color

    def save(self, *paths: Path, dpi: int = 200) -> list[Path]:
        self.figure.tight_layout()
        written = []
        for path in paths:
            path = Path(path)
            path.parent.mkdir(parents=True, exist_ok=True)
            self.figure.savefig(path, dpi=dpi)
            written.append(path)
        plt.close(self.figure)
        return written


class CcdfFigure(Figure):
    """Complementary CDF of peak AoI, one curve per run."""

    def __init__(self, title: str, figsize: tuple[float, float] = (6.0, 4.2),
                 xlabel: str = "Peak age of information (ms)",
                 ylabel: str = "CCDF   P(PAoI $\\geq$ x)",
                 log_x: bool = False):
        super().__init__(title, figsize)
        self.axes.set(xlabel=xlabel, ylabel=ylabel)
        self.axes.set_yscale("log")
        if log_x:
            self.axes.set_xscale("log")
        self.axes.grid(True, which="major", alpha=0.25, linewidth=0.6)
        self.axes.grid(True, which="minor", axis="y", alpha=0.12, linewidth=0.4)
        self.axes.set_axisbelow(True)
        self._floor = 1.0

    def add(self, series, color: str | None = None, linestyle: str = "-") -> None:
        x, y = series.ccdf()
        self.axes.plot([value * 1000 for value in x], y,
                       color=color or self._next_color(),
                       linewidth=2.0, linestyle=linestyle,
                       label=f"{series.label} (n={len(series)})")
        self._floor = min(self._floor, y[-1])

    def finish(self, annotate_quantile: float | None = 0.99) -> None:
        """Set the tail limit and the legend once every curve has been added."""
        # One decade of headroom below the coarsest curve keeps the last few
        # samples off the axis line, where they would be unreadable.
        self.axes.set_ylim(self._floor / 2, 1.05)
        self.axes.set_xlim(left=0)
        if annotate_quantile is not None:
            self.axes.axhline(1 - annotate_quantile, color=TEXT_SECONDARY,
                              linewidth=0.8, linestyle=":", zorder=0)
            self.axes.annotate(f"p{annotate_quantile * 100:g}",
                               xy=(0.995, 1 - annotate_quantile),
                               xycoords=("axes fraction", "data"),
                               ha="right", va="bottom",
                               fontsize=8, color=TEXT_SECONDARY)
        self.axes.legend(frameon=False, loc="upper right")

    def save(self, *paths: Path, dpi: int = 200) -> list[Path]:
        if self.axes.get_legend() is None:
            self.finish()
        return super().save(*paths, dpi=dpi)


class AoiTimelineFigure(Figure):
    """Age against simulation time, with optional peaks, trend and event bands.

    Three marks can share these axes, which is what the AoI/PAoI/both modes
    are: ``add`` draws the continuous sawtooth, ``add_peaks`` draws only the
    tip of each ramp, and ``add_trend`` smooths those tips.
    """

    def __init__(self, title: str, figsize: tuple[float, float] = (16.0, 5.5),
                 ylabel: str = "Age of Information (ms)"):
        super().__init__(title, figsize)
        self.axes.set(xlabel="Simulation time (s)", ylabel=ylabel)
        self.axes.grid(True, alpha=0.25)
        self.axes.set_axisbelow(True)

    def add(self, trace, label: str = "AoI", color: str | None = None) -> None:
        x, y = zip(*trace.points)
        self.axes.plot(x, [value * 1000 for value in y],
                       color=color or self._next_color(), linewidth=1.0, label=label)

    def add_peaks(self, trace, label: str = "peak AoI",
                  color: str | None = None) -> None:
        """The peaks as markers, never as a line.

        Peak AoI has no value between receptions, so joining the points would
        invent one.
        """
        self.axes.plot([peak.time for peak in trace.peaks],
                       [peak.value * 1000 for peak in trace.peaks],
                       linestyle="none", marker=".", markersize=3.0,
                       color=color or PEAK_COLOR, label=label)

    def add_trend(self, trace, window: int, label: str | None = None,
                  color: str | None = None) -> None:
        times, values = moving_average([peak.time for peak in trace.peaks],
                                       [peak.value * 1000 for peak in trace.peaks],
                                       window)
        if not times:
            return
        self.axes.plot(times, values, color=color or TREND_COLOR, linewidth=1.8,
                       label=label or f"running mean ({window} samples)")

    def mark_span(self, start: float, end: float, label: str, color: str) -> None:
        self.axes.axvspan(start, end, color=color, alpha=0.10, label=label)
        self.axes.axvline(start, color=color, linestyle="--", linewidth=1)

    def finish(self, end_time: float) -> None:
        self.axes.set_xlim(0, end_time)
        self.axes.set_ylim(bottom=0)
        self.axes.margins(x=0)
        self.axes.legend(frameon=False)
