# Analysis

Result post-processing shared by every scenario. Nothing here runs a
simulation; it all reads the `.vec` files a run leaves behind.

```
analysis/
├── plot_paoi_ccdf.py     The only CCDF entry point
├── paoi/                 The library
│   ├── vectors.py        Reads OMNeT++ .vec files
│   ├── aoi.py            Reconstructs age of information from the vectors
│   ├── plots.py          Figure classes -- all styling lives here
│   ├── scenario.py       RunSpec / Scenario: what one curve, one figure is
│   └── scenarios.py      The registry: the figures this project publishes
└── figures/              Generated PDFs and PNGs
```

The layering runs one way: `vectors` knows about files, `aoi` knows about
age, `plots` knows about matplotlib, and only `scenarios` knows which
simulation produced what. Restyling therefore never touches the
reconstruction, and registering a figure never touches the styling.

## Regenerating a figure

```bash
./plot_paoi_ccdf.py --scenario 5g-tsn
./plot_paoi_ccdf.py --all
```

Paths in the registry are anchored at the `simulations` tree, so these work
from any directory. Output goes to `figures/paoi-ccdf-<scenario>.pdf` and
`.png`.

Registered scenarios:

| Name | Demo | Critical-stream receiver |
|---|---|---|
| `5g-tsn` | `demos/tas_comparison` | `TasComparisonNetwork.tsnDeviceB.app[0]` |
| `tsn-standalone` | `demos/tsn_standalone` | `TsnStandaloneNetwork.tsnDeviceC.app[0]` |

Each draws two curves from the demo's `Baseline` and `Tas` configurations.
Run both configurations first -- see the demo's own README -- since
`results/` is not tracked in git.

## Adding a scenario

Add an entry to `SCENARIOS` in `paoi/scenarios.py`. It becomes a `--scenario`
choice automatically; no new script is needed. A demo whose result layout
matches the usual `results/baseline` + `results/tas` pair is a one-liner via
`_tas_comparison_runs`.

## One-off figures

For anything not worth registering, describe the curves on the command line:

```bash
./plot_paoi_ccdf.py --module TsnStandaloneNetwork.tsnDeviceC.app[0] \
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

## Timelines

`demos/uplink_test/analyze_aoi.py` draws the AoI sawtooth against simulation
time rather than a CCDF, using `AoiTimelineFigure` from the same library. It
stays a separate script because its figure is annotated with scenario events
(the SINR drop, the leg switch) that no other run has.
