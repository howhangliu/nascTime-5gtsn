# Analysis

Result post-processing shared by every scenario. Nothing here runs a
simulation; it all reads the `.vec` files a run leaves behind.

```
analysis/
├── plot_aoi.py           The only plotting entry point
├── paoi/                 The library
│   ├── vectors.py        Reads OMNeT++ .vec files
│   ├── aoi.py            Reconstructs age of information from the vectors
│   ├── plots.py          Figure classes -- all styling lives here
│   ├── scenario.py       RunSpec / Scenario: what one curve, one figure is
│   ├── scenarios.py      The registry: the figures this project publishes
│   └── dataset.py        The committed extract of a run's receptions
├── data/                 Those extracts -- ~200 KB, tracked in git
└── figures/              Generated PDFs and PNGs
```

The layering runs one way: `vectors` knows about files, `aoi` knows about
age, `plots` knows about matplotlib, and only `scenarios` knows which
simulation produced what. Restyling therefore never touches the
reconstruction, and registering a figure never touches the styling.

## Regenerating a figure

```bash
./plot_aoi.py --scenario 5g-tsn
./plot_aoi.py --all
```

Paths in the registry are anchored at the `simulations` tree, so these work
from any directory. Output goes to `figures/paoi-<mode>-<scenario>.pdf`
and `.png`.

This works in a fresh clone, with no simulation run and no result files. See
"Datasets" below.

Registered scenarios:

| Name | Demo | Default mode | What it shows |
|---|---|---|---|
| `5g-tsn` | `demos/tas_comparison` | `ccdf` | critical stream, Baseline vs TAS |
| `tsn-standalone` | `demos/tsn_standalone` | `ccdf` | critical stream, Baseline vs TAS |
| `uplink-failover` | `demos/uplink_test` | `timeline` | critical stream through SINR loss and failover |
| `uplink-failover-be` | `demos/uplink_test` | `timeline` | the same run's best-effort stream |

## Modes

Each scenario has a default figure, which `--mode` overrides:

| Mode | Figure |
|---|---|
| `ccdf` | the peak-AoI distribution, one curve per run |
| `timeline` | the AoI sawtooth against simulation time |
| `peaks` | peak AoI against time, one marker per reception |
| `both` | the sawtooth with its peaks marked |

`peaks` draws markers rather than a line on purpose: peak AoI has no value
between receptions, so joining the points would invent one. `--window N`
overlays a running mean over N consecutive samples — at ~1000 receptions per
second, `--window 50` smooths over roughly 50 ms.

```bash
./plot_aoi.py --scenario uplink-failover --mode peaks --window 50
./plot_aoi.py --scenario 5g-tsn --mode timeline --only TAS
```

`--only TEXT` keeps just the runs whose label contains TEXT.

## Phases

A scenario can name the stretches of its run — `Phase(start, end, label,
color)` in the registry. Timelines band them, and every mode reports
per-phase peak-AoI statistics, which for an event-driven run is the whole
contrast:

```
0-1s healthy active path:    n=975 mean=13.832 ms p99=48.180 ms max=58.163 ms
1-2s degraded active path:   n=784 mean=33.870 ms p99=44.663 ms max=49.673 ms
2-3s traffic on standby path: n=993 mean=14.533 ms p99=47.201 ms max=56.163 ms
```

A phase with `shade=False` is reported but not banded — the stretch a run
starts from is the reference, not an event.

## Datasets

A 90 s run leaves an 8-12 MB `.vec` file, and `results/` is not tracked in
git -- too large to push, and a collaborator who cannot fetch it cannot
redraw the figure. So each run names two sources:

| | Path | Size | In git |
|---|---|---|---|
| Raw results | `demos/<demo>/results/…/*.vec` | 8-12 MB | no |
| Dataset | `data/<scenario>-<config>.csv.gz` | 29-83 KB | **yes** |

A run reads its `.vec` when one is present and falls back to the dataset
otherwise, so whoever just ran the simulation and whoever only cloned the
repository get the same numbers -- exactly the same, not merely close: the
dataset stores `repr` of each float, which reads back as the same double.

The dataset holds the receptions (time, delay, sequence), not the finished
CCDF, so quantiles, the stationarity split and the AoI timeline are all still
derivable from it. Only the diagnostics that no figure reads -- queue
occupancy, gate state, the best-effort sink -- stay behind in the `.vec`.

After re-running a simulation, refresh the datasets and commit them
alongside the figures:

```bash
./plot_aoi.py --all --export
```

## Adding a scenario

Add an entry to `SCENARIOS` in `paoi/scenarios.py`. It becomes a `--scenario`
choice automatically; no new script is needed. A demo whose result layout
matches the usual `results/baseline` + `results/tas` pair is a one-liner via
`_tas_comparison_runs`, which also names its datasets. Then run
`./plot_aoi.py --scenario <name> --export` and commit the result, so
the new figure is reproducible without the raw results.

## One-off figures

For anything not worth registering, describe the curves on the command line:

```bash
./plot_aoi.py --module TsnStandaloneNetwork.tsnDeviceC.app[0] \
    --run "Baseline=../demos/tsn_standalone/results/baseline/Baseline-#0.vec" \
    --run "TAS=../demos/tsn_standalone/results/tas/Tas-#0.vec" \
    --output /tmp/check.pdf
```

`--csv` writes the plotted points beside the figure, and
`--check-stationarity` reports each run's two halves — a queue that has not
reached steady state gives quantiles that are a function of `sim-time-limit`
rather than of the system.

## Restyling

Everything visual is in `paoi/plots.py`: `SERIES_COLORS` for the curve
colours, the `rcParams` block for fonts and axis ink, and
`CcdfFigure.__init__` / `finish` for the axes, grid, legend and p99 marker.
Both published figures follow a change there.

## Restyling a timeline

`AoiTimelineFigure` in `paoi/plots.py` carries the sawtooth (`add`), the peak
markers (`add_peaks`) and the running mean (`add_trend`); `PEAK_COLOR` and
`TREND_COLOR` beside `SERIES_COLORS` are the two marks a timeline adds. Phase
band colours are per-scenario, in the registry.
