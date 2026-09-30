"""Peak-age-of-information analysis for nascTime result files.

Typical use::

    from paoi import RunSpec, CcdfFigure

    figure = CcdfFigure("Critical stream, 5G-TSN bridge")
    for run in runs:
        figure.add(run.peak_series())
    figure.save("paoi-ccdf.pdf")
"""

from .aoi import AoiTrace, PeakAoiSeries, PeakSample, Reception
from .dataset import read_receptions, write_receptions
from .plots import AoiTimelineFigure, CcdfFigure
from .scenario import RunSpec, Scenario
from .scenarios import DATA_DIR, FIGURES_DIR, SCENARIOS, figure_path
from .vectors import Sample, VectorFile

__all__ = [
    "AoiTimelineFigure", "AoiTrace", "CcdfFigure", "DATA_DIR", "FIGURES_DIR",
    "PeakAoiSeries", "PeakSample", "Reception", "RunSpec", "SCENARIOS", "Sample",
    "Scenario", "VectorFile", "figure_path", "read_receptions", "write_receptions",
]
