# TAS comparison demo

This demo runs the same two traffic sources through the 5G–TSN bridge:

- `critical`: 200-byte packet every 10 ms;
- `best-effort`: uniformly distributed 1200–1450-byte packet size and an
  exponentially distributed 500 us mean inter-arrival time.

`Baseline` uses ordinary FIFO queues at the NW-TT and DS-TT. Both flows are
best effort. `Tas` maps critical traffic to PCP/QFI 6, best effort to PCP/QFI
0, and applies this repeating schedule at both TT TSN-facing egress ports:

| Cycle time | Gate 6 (critical) | Gate 1 (best effort) |
|---|---|---|
| 0–1 ms | open | closed |
| 1–9 ms | closed | open |
| 9–10 ms | closed | closed |

With eight traffic classes, INET's standard IEEE 802.1Q mapping places PCP 0
in traffic class 1 and PCP 6 in traffic class 6. Both QFIs share DRB 0 in this
demo so the measured difference comes from Ethernet priority and TAS.

The DS-TT-to-device link is intentionally limited to 10 Mbps while the mean
best-effort offered load is about 9.6 Mbps. This creates repeatable contention:
the baseline FIFO delays critical packets behind large background packets,
whereas TAS gives critical traffic an exclusive transmission window.

The load is deliberately just below capacity rather than above it. At ~0.98
utilisation the queue is heavily congested but stable, so delay and peak AoI
have distributions to measure. Overloading the link (an earlier revision
offered 21.6 Mbps) destroys that: the backlog grows for the whole run, and
every quantile becomes a function of `sim-time-limit` rather than a property of
the system.

## How TAS is added

Setting `hasEgressTrafficShaping = true` replaces each translator's ordinary
Ethernet `PacketQueue` with INET's `Ieee8021qTimeAwareShaper`. The `Tas` config
enables it at these egress ports:

- `nwTt.ethIf.macLayer.queue`;
- `dsTt.tsnEth.macLayer.queue`.

The source stream encoder assigns PCP 6 to critical traffic and PCP 0 to
best-effort traffic. NW-TT maps PCP to DSCP for transport through the 5GS, and
DS-TT restores that value as `PcpReq` before Ethernet queuing. At startup,
`TsnAf` reads the GCL in `cnc_tas.xml`, validates that it covers the full cycle,
and programs the `PeriodicGate` instances inside both INET shapers. The
`Baseline` config leaves shaping disabled, providing the FIFO comparison.

## Run and compare

Open `omnetpp.ini` in the OMNeT++ IDE and run `Baseline`, followed by `Tas`.
Both configurations use seed 42, so they receive the same random best-effort
traffic sequence. Results are written separately to `results/baseline` and
`results/tas`.

In Analysis, compare the following results:

- `tsnDeviceB.app[0] / endToEndDelay`: critical-stream latency;
- `tsnDeviceB.app[1] / endToEndDelay`: best-effort latency;
- `packetReceived:count`: delivery count for each stream;
- `dsTt.tsnEth.macLayer.queue / queueLength`: total FIFO/TAS backlog;
- `dsTt.tsnEth.macLayer.queue.queue[1|6] / queueLength`: holding behavior;
- `dsTt.tsnEth.macLayer.queue.transmissionGate[1|6] / gateState`: GCL timing.

For the TAS run, gate 6 should be open for the first millisecond of each 10 ms
cycle, gate 1 should be open from 1 to 9 ms, and both should be closed for the
final millisecond. Critical packets generated every 10 ms are aligned with the
same cycle period; their actual gate arrival phase also includes 5G transit
delay.

## Peak age of information

`plot_paoi_ccdf.py` draws the CCDF of the critical stream's peak AoI for both
configurations on one set of axes:

Source the OMNeT++, INET, Simu5G and nascTime `setenv` scripts first (see the
top-level README) so that `opp_run` is on `PATH` and `INET_ROOT` / `SIMU5G_ROOT`
are set. Then, from this directory:

```
../../../bin/nasctime-run.sh -u Cmdenv -c Baseline -f omnetpp.ini
../../../bin/nasctime-run.sh -u Cmdenv -c Tas -f omnetpp.ini
./plot_paoi_ccdf.py
```

The figure lands in `figures/paoi-ccdf-5g-tsn.pdf`. The reconstruction lives in
`simulations/analysis/paoi`, shared with the standalone TSN scenario and the
uplink demo; `simulations/analysis/plot_paoi_ccdf.py` is its general CLI.

Peak AoI for a periodic stream is the sampling period plus the delivery delay
of the update that ends the gap, so a lost update widens the following peak
instead of producing one of its own.

## Reference result (seed 42, 90 s run, 10 s warm-up)

Peak AoI of the critical stream, in milliseconds:

| | Baseline | TAS |
|---|---:|---:|
| samples | 7967 | 7973 |
| mean | 38.9 | 20.8 |
| p99 | 96.3 | 40.2 |
| maximum | 110.5 | 50.2 |

TAS halves the mean and cuts the 99th percentile by 2.4x, and -- the point of
plotting a CCDF rather than a mean -- it bounds the tail: the TAS curve is a
staircase whose steps are whole 10 ms gate cycles, ending at 50 ms, while the
baseline runs smoothly out past 110 ms. The staircase is the gate cycle showing
through: variable 5G transit randomises the phase at which a critical packet
reaches the DS-TT gate, so it waits an integer number of cycles.

The trade-off is intentional: the critical class gets a protected 1 ms window,
while the best-effort class receives less service under TAS (its 8 ms window
caps it at 8 Mbps, below the 9.6 Mbps offered).

See [`../tsn_standalone`](../tsn_standalone) for the same experiment without the
5G bridge, where the talker happens to be phase-aligned with the gate cycle.
