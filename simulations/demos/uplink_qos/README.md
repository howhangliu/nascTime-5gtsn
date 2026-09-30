# Uplink QoS demo

Use `omnetpp.ini` for the QoS experiment. It uses the dedicated
`UplinkQosNetwork`, which contains exactly one path:

```text
TSN Device B -> DS-TT -> UE -> gNB -> UPF -> NW-TT -> TSN Device A
```

It intentionally has no TSN switch, standby UE, second DS-TT, ScenarioManager,
RouteSwitcher, TSN AF, BMCA, gPTP modules, or gPTP sideband. The separate
`../uplink_test` demo remains available for radio impairment and failover.

## Configurations

The two configurations use identical topology, traffic, radio geometry, and
random seed. The critical source sends 200-byte packets every 1 ms (1.6 Mbps),
while best effort sends 1000-byte packets every 500 us (16 Mbps). This mirrors
the working downlink experiment's small critical/heavy background load shape
and creates sustained radio contention without making the critical bearer
itself permanently backlogged:

- `Baseline`: untagged traffic, QFI/DRB 0, and the `MAXCI` uplink scheduler.
- `Qos`: UDP port 5000 is PCP 6 and port 5001 is PCP 0. The DS-TT translates
  PCP to DSCP, UE SDAP maps DSCP to QFI, and QFI 6 selects DRB 1. SDAP assigns
  DRB 1 to the UE's `CONVERSATIONAL` logical-channel group and DRB 0 to
  `BACKGROUND`, so UE MAC serves the high-priority DRB first in each UL grant.

Both applications set DSCP 0 themselves. Thus QFI 6 can only appear if the
complete PCP -> DSCP -> ToS metadata -> QFI chain works.

The critical load is deliberately much smaller than uplink capacity. An
earlier equal-load version offered a continuously backlogged 16 Mbps critical
bearer; strict logical-channel priority then consumed every grant and starved
best effort. That was an overloaded priority test, not a valid stable QoS
comparison.

## Validate and compare

From this directory, run:

```sh
python3 analyze_qos.py
```

The analyzer reports count, mean, p50, p95, and p99 end-to-end latency for
both flows. It also validates bearer use:

```text
Baseline: DRB check PASS (DRB 0 only)
Qos:     DRB check PASS (DRB 0 and DRB 1)
```

Do not interpret the latency comparison unless both checks pass.
The analyzer also fails if either receiver stream has zero samples; QoS must
prioritize DRB 1 without starving DRB 0.

## Reference result

With seed 42, a 5 s run, and a 1 s warm-up, the validated implementation gave:

| Flow | Baseline mean / p95 | QoS mean / p95 | QoS samples |
|---|---:|---:|---:|
| Critical, PCP 6 | 33.179 / 39.013 ms | 20.166 / 34.505 ms | 3686 |
| Best effort, PCP 0 | 33.407 / 39.020 ms | 36.329 / 42.010 ms | 5737 |

Best effort continued throughout all four measured one-second intervals
(1427, 1441, 1440, and 1429 receptions), demonstrating priority without
starvation. Exact values may change with Simu5G or INET versions; the required
invariants are two active DRBs, nonzero delivery for both flows, and lower
critical-stream latency in `Qos` than in `Baseline`.

## Implementation boundary

The gNB schedules uplink resources for the UE as a whole. The UE MAC then
selects which logical channel fills each grant. Consequently, copying the
downlink `QOS_PF` configuration to the gNB uplink scheduler does not prioritize
two DRBs belonging to the same UE. In this demo SDAP assigns DRB 1 to the
`CONVERSATIONAL` LCG and DRB 0 to `BACKGROUND`; the NR UE reports the residual
aggregate backlog of both DRBs in its BSR so the lower class remains visible.
