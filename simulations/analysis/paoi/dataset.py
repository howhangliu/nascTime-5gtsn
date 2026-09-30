"""The receptions behind a figure, small enough to commit.

A 90 s run leaves a multi-megabyte ``.vec`` file, most of it diagnostics that
no figure reads. Everything the peak-AoI reconstruction actually needs is three
columns per delivered update, which gzips down to tens of kilobytes -- small
enough to live in git, so a collaborator can restyle or re-cut a figure without
re-running the simulation or fetching the raw results.

The columns are the receptions themselves, not the finished CCDF: quantiles,
the stationarity split and the AoI timeline are all still derivable, because
:class:`~paoi.aoi.AoiTrace` rebuilds from exactly this.

Values round-trip exactly -- ``repr`` of a float is the shortest string that
reads back as the same double -- so a figure drawn from a dataset is identical
to one drawn from the ``.vec`` it came from, not merely close.
"""

from __future__ import annotations

import csv
import gzip
from pathlib import Path

from .aoi import Reception

FORMAT = "paoi-receptions v1"
COLUMNS = ["time_s", "delay_s", "sequence"]


def write_receptions(path: Path, receptions: list[Reception], *, module: str,
                     end_time: float | None = None, source: str | None = None) -> Path:
    """Write `receptions` to a gzipped CSV, creating parent directories."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt", newline="", encoding="utf-8") as handle:
        handle.write(f"# {FORMAT}\n")
        handle.write(f"# module: {module}\n")
        if source is not None:
            handle.write(f"# source: {source}\n")
        if end_time is not None:
            handle.write(f"# end_time: {end_time!r}\n")
        writer = csv.writer(handle)
        writer.writerow(COLUMNS)
        writer.writerows(
            (repr(r.time), repr(r.delay), r.sequence) for r in receptions)
    return path


def read_receptions(path: Path) -> tuple[list[Reception], float | None]:
    """Read a dataset back as (receptions, end_time)."""
    path = Path(path)
    end_time: float | None = None
    rows: list[str] = []
    with gzip.open(path, "rt", encoding="utf-8") as handle:
        for line in handle:
            if not line.startswith("#"):
                rows.append(line)
                continue
            key, separator, value = line[1:].strip().partition(": ")
            if separator and key == "end_time":
                end_time = float(value)

    reader = csv.reader(rows)
    header = next(reader, None)
    if header != COLUMNS:
        raise ValueError(f"{path} is not a {FORMAT} dataset (columns: {header})")
    receptions = [Reception(float(time), float(delay), int(sequence))
                  for time, delay, sequence in reader]
    if not receptions:
        raise ValueError(f"{path} contains no receptions")
    return receptions, end_time
