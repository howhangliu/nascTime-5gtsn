"""Peak-age-of-information analysis for nascTime result files.

Typical use::

    from paoi import RunSpec, CcdfFigure

    figure = CcdfFigure("Critical stream, 5G-TSN bridge")
    for run in runs:
        figure.add(run.peak_series())
    figure.save("paoi-ccdf.pdf")
"""

from .aoi import AoiTrace, PeakAoiSeries, PeakSample, Reception
from .plots import AoiTimelineFigure, CcdfFigure
from .scenario import RunSpec, Scenario
from .vectors import Sample, VectorFile

__all__ = [
    "AoiTimelineFigure", "AoiTrace", "CcdfFigure", "PeakAoiSeries", "PeakSample",
    "Reception", "RunSpec", "Sample", "Scenario", "VectorFile",
]
