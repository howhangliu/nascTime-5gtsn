"""The named figures this project publishes.

A scenario is a table entry, not a script. Everything that distinguishes one
figure from another -- which demo produced the results, which application
received the critical stream, what the curves are called -- lives here, so
``plot_paoi_ccdf.py`` stays a single CLI over the whole set.

Paths are anchored at the ``simulations`` tree rather than at the caller's
working directory, so ``--scenario`` behaves the same from anywhere.
"""

from __future__ import annotations

from pathlib import Path

from .scenario import RunSpec, Scenario

SIMULATIONS_DIR = Path(__file__).resolve().parents[2]
DEMOS_DIR = SIMULATIONS_DIR / "demos"
FIGURES_DIR = SIMULATIONS_DIR / "analysis" / "figures"
DATA_DIR = SIMULATIONS_DIR / "analysis" / "data"

# Both demos ship the same pair of configurations, and OMNeT++ names result
# files after the config, so the two result paths follow from the demo alone.
BASELINE_VEC = "results/baseline/Baseline-#0.vec"
TAS_VEC = "results/tas/Tas-#0.vec"


def _tas_comparison_runs(name: str, demo: str, receiver: str) -> tuple[RunSpec, ...]:
    """The Baseline/TAS pair for one demo directory.

    Each run names both sources: the untracked ``.vec`` it was measured from,
    and the committed dataset that stands in for it after a fresh clone.
    """
    root = DEMOS_DIR / demo
    return (
        RunSpec(root / BASELINE_VEC, receiver, "Baseline (FIFO)",
                DATA_DIR / f"{name}-baseline.csv.gz"),
        RunSpec(root / TAS_VEC, receiver, "TAS",
                DATA_DIR / f"{name}-tas.csv.gz"),
    )


SCENARIOS: dict[str, Scenario] = {
    scenario.name: scenario
    for scenario in (
        Scenario(
            name="5g-tsn",
            title="Critical stream over the 5G-TSN bridge",
            runs=_tas_comparison_runs(
                "5g-tsn", "tas_comparison", "TasComparisonNetwork.tsnDeviceB.app[0]"),
        ),
        Scenario(
            name="tsn-standalone",
            title="Critical stream across a standalone TSN switch",
            runs=_tas_comparison_runs(
                "tsn-standalone", "tsn_standalone",
                "TsnStandaloneNetwork.tsnDeviceC.app[0]"),
        ),
    )
}


def figure_path(scenario: Scenario, suffix: str = ".pdf") -> Path:
    """Where a registered scenario's figure belongs."""
    return FIGURES_DIR / f"paoi-ccdf-{scenario.name}{suffix}"
