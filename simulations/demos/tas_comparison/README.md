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
best-effort offered load is about 21.6 Mbps. This creates repeatable contention:
the baseline FIFO delays critical packets behind large background packets,
whereas TAS gives critical traffic an exclusive transmission window.

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

## Reference result (seed 42)

The checked configuration was run for 2 s with a 100 ms warm-up. The recorded
results show that TAS is active and isolates the critical stream, although its
latency includes one or occasionally two 10 ms gate cycles:

| Metric | Baseline | TAS |
|---|---:|---:|
| Critical packets received | 80 | 178 |
| Critical mean / maximum delay | 508.5 / 1038.1 ms | 12.55 / 20.20 ms |
| Best-effort packets received | 1691 | 1316 |
| Best-effort mean / maximum delay | 524.1 / 1039.1 ms | 619.5 / 1235.5 ms |

The trade-off is intentional: the critical class gets a protected 1 ms window,
while the overloaded best-effort class receives less service. Gate vectors also
confirm that class 6 is open from 0–1 ms and class 1 from 1–9 ms in each cycle.
