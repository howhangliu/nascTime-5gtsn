# Standalone TSN comparison

The control experiment for [`../tas_comparison`](../tas_comparison): the same
two streams, the same gate control list, the same 10 Mbps bottleneck — but no
5G bridge in the path. Comparing the two answers what the 5G leg costs the
critical stream, because everything else is held fixed.

## Topology

```
tsnDeviceA (critical) ──1G──┐
                            ├── tsnSwitch ──10M── tsnDeviceC (both sinks)
tsnDeviceB (best effort) ─1G─┘
```

- `critical`: 200-byte packet every 10 ms, from `tsnDeviceA`;
- `best-effort`: 1200–1450-byte packets, exponential 1.165 ms mean
  inter-arrival (~9.6 Mbps), from `tsnDeviceB`.

The two streams first meet inside the switch and contend for `eth2`, the only
10 Mbps link. That port is the standalone counterpart of the DS-TT's TSN-facing
port in the 5G-TSN scenario: same speed, same offered load, same GCL.

`tsnDeviceC` runs two `UdpSink`s. `app[0]` is the critical sink in both
scenarios, so the analysis scripts point at the same application index either
way.

## Configurations

`Baseline` uses an ordinary FIFO queue at the switch egress; both flows are
best effort. `Tas` tags critical traffic PCP 6 and background traffic PCP 0 at
the senders, and applies this repeating schedule at `tsnSwitch.eth[2]`:

| Cycle time | Gate 6 (critical) | Gate 1 (best effort) |
|---|---|---|
| 0–1 ms | open | closed |
| 1–9 ms | closed | open |
| 9–10 ms | closed | closed |

The schedule is read from `../tas_comparison/cnc_tas.xml` — the same file the
5G-TSN scenario programs into its TT shapers, so the two cannot drift apart.
`TsnAf` loads it and programs the switch's `PeriodicGate` instances. Its
`nwTtModule`/`dsTtModule`/`gnbModule` parameters are empty here: there is no
5GS, and the AF's only job is the shaper.

With eight traffic classes, INET's standard IEEE 802.1Q mapping places PCP 0 in
traffic class 1 and PCP 6 in traffic class 6 — the classes the GCL opens.

## Run and plot

```
../../../bin/nasctime-run -u Cmdenv -c Baseline -f omnetpp.ini
../../../bin/nasctime-run -u Cmdenv -c Tas -f omnetpp.ini
./plot_paoi_ccdf.py
```

The figure lands in `figures/paoi-ccdf-tsn-standalone.pdf`.

## Reference result (seed 42, 90 s run, 10 s warm-up)

Peak AoI of the critical stream, in milliseconds:

| | Baseline | TAS |
|---|---:|---:|
| samples | 5803 | 5799 |
| mean | 30.6 | 10.209 |
| p99 | 83.8 | 10.209 |
| maximum | 95.9 | 10.209 |

TAS is exactly deterministic here, and the reason is worth knowing before
quoting the number: the talker's 10 ms period and the 10 ms gate cycle both
start at t=0, so every critical packet meets an open gate and leaves after one
transmission time (0.209 ms) with no queueing at all. Peak AoI is then the
10 ms sampling period plus that fixed delay, every single time.

That is the best case a time-aware shaper can produce — a perfectly
phase-aligned talker. To measure the unaligned case instead, offset the talker
against the cycle:

    *.tsnDeviceA.app[0].startTime = 100ms + 4ms

The 5G-TSN scenario has no such alignment: variable 5G transit randomises the
phase at which packets reach the DS-TT gate, which is why its TAS curve is a
staircase across gate cycles rather than a single point.

## Load and stationarity

Best-effort load is set to about 0.98 utilisation of the 10 Mbps link — heavily
congested but stable, so peak AoI has a distribution to measure. An overloaded
link has none: its backlog grows for the whole run, and every quantile becomes
a function of `sim-time-limit` rather than a property of the system. After
changing the load or the schedule, check that the queue actually reached
steady state:

```
../../analysis/plot_paoi_ccdf.py --module TsnStandaloneNetwork.tsnDeviceC.app[0] \
    --run "Baseline=results/baseline/Baseline-#0.vec" \
    --run "TAS=results/tas/Tas-#0.vec" \
    --check-stationarity --output /tmp/check.pdf
```

If a run's second half is visibly worse than its first, the transient is still
inside the measurement: raise `warmup-period`, or lower the offered load.
