"""Reading OMNeT++ ``.vec`` output files.

Only the small subset needed for age-of-information work is implemented: pull
named vectors belonging to one module, plus the run's simulation time limit.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


VECTOR_RE = re.compile(r'^vector\s+(\d+)\s+(\S+)\s+(\S+)\s+([A-Z]+)')
SIM_LIMIT_RE = re.compile(r'^config\s+sim-time-limit\s+([0-9.eE+-]+)s\s*$')


@dataclass(frozen=True)
class Sample:
    """One recorded value, tagged with the event that produced it."""

    event: int
    time: float
    value: float


class VectorFile:
    """A single OMNeT++ ``.vec`` result file."""

    def __init__(self, path: Path):
        self.path = Path(path)
        self._sim_time_limit: float | None = None
        self._header_read = False

    @property
    def sim_time_limit(self) -> float | None:
        """The run's ``sim-time-limit``, or None if the header lacked one."""
        if not self._header_read:
            self._read_header()
        return self._sim_time_limit

    def read(self, module: str, names: Iterable[str]) -> dict[str, list[Sample]]:
        """Return the named vectors of `module`, in file order.

        Names are given without the ``:vector`` suffix that OMNeT++ appends,
        e.g. ``read(module, ["endToEndDelay", "rcvdPkSeqNo"])``.
        """
        wanted = {f"{name}:vector" for name in names}
        samples: dict[str, list[Sample]] = {name: [] for name in wanted}
        columns: dict[int, str] = {}
        id_to_name: dict[int, str] = {}

        with self.path.open("r", encoding="utf-8", errors="replace") as handle:
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
                # Keep the first value: a later [General] value may be present
                # in the header but is overridden by the selected configuration.
                if match and not self._header_read:
                    self._sim_time_limit = float(match.group(1))
                    self._header_read = True
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
                samples[id_to_name[vector_id]].append(sample)

        self._header_read = True  # a full pass settles the question either way
        return {name.removesuffix(":vector"): values for name, values in samples.items()}

    def modules_with(self, name: str) -> list[str]:
        """Every module that recorded a vector called `name`.

        Useful for pointing a user at the right ``--module`` when their guess
        does not exist in the file.
        """
        found = []
        target = f"{name}:vector"
        with self.path.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                match = VECTOR_RE.match(line)
                if match and match.group(3) == target:
                    found.append(match.group(2))
        return found

    def _read_header(self) -> None:
        with self.path.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                match = SIM_LIMIT_RE.match(line)
                if match:
                    self._sim_time_limit = float(match.group(1))
                    break
                if line and line[0].isdigit():
                    break
        self._header_read = True
