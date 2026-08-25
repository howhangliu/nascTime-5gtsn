"""The named figures this project publishes.

A scenario is a table entry, not a script. Everything that distinguishes one
figure from another -- which demo produced the results, which application
received the critical stream, what the curves are called -- lives here, so
``plot_aoi.py`` stays a single CLI over the whole set.

Paths are anchored at the ``simulations`` tree rather than at the caller's
working directory, so ``--scenario`` behaves the same from anywhere.
"""

from __future__ import annotations

from pathlib import Path

from .scenario import Phase, RunSpec, Scenario

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


# The uplink failover run is a single simulation watched over time rather
# than two configurations compared, so its curves are its two streams and its
# story is in the phases: the channel degrades, then the route changes.
UPLINK_VEC = "results/uplink/UplinkSinrFailoverAoI-#0.vec"
UPLINK_RECEIVER = "UplinkNetwork.tsnDeviceA"


UPLINK_PHASES = (
    Phase(0.0, 1.0, "healthy active path", "#2a78d6", shade=False),
    Phase(1.0, 2.0, "degraded active path", "#e34948"),
    Phase(2.0, 3.0, "traffic on standby path", "#008300"),
)


def _uplink_scenario(name: str, stream: int, label: str, slug: str) -> Scenario:
    """One stream of the failover run.

    The two streams share a simulation but not a figure: they track each other
    closely -- same radio, same degradation -- so drawing them on one set of
    axes hides the sawtooth rather than comparing anything.
    """
    root = DEMOS_DIR / "uplink_test"
    return Scenario(
        name=name,
        title=f"Uplink SINR degradation and failover — {label}",
        runs=(RunSpec(root / UPLINK_VEC, f"{UPLINK_RECEIVER}.app[{stream}]", label,
                      DATA_DIR / f"uplink-failover-{slug}.csv.gz"),),
        phases=UPLINK_PHASES,
        default_mode="timeline",
        end_time=3.0,
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
        _uplink_scenario("uplink-failover", 0, "Critical (DSCP 6, 1 ms)", "critical"),
        _uplink_scenario("uplink-failover-be", 1, "Best effort", "best-effort"),
    )
}


def figure_path(scenario: Scenario, mode: str, suffix: str = ".pdf") -> Path:
    """Where a registered scenario's figure belongs."""
    return FIGURES_DIR / f"paoi-{mode}-{scenario.name}{suffix}"
