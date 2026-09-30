# AGV fleet SUMO + FRER demo

This demo implements the floor plan and ten-UE traffic table from the AGV Fleet
Demo Buildsheet. The 100 m x 100 m canvas follows the document's A-E / 0-4
grid, with gNB1 and gNB2 displayed at `(0, 50, 8)` and `(100, 50, 8)`.
Their radio coordinates are shifted 6.1 m outward to `(-6.1, 50, 8)` and
`(106.1, 50, 8)`: Simu5G's indoor NLOS model is undefined below 6 m, while the
documented antenna positions coincide exactly with loop waypoints A2 and E2.
Internally, the padding boundary and Veins' 1 m TraCI margin make the
corresponding OMNeT++ radio coordinates `(-4.1, 52, 8)` and `(108.1, 52, 8)`.

| Area | SUMO route | UEs | Speed | Stream |
|---|---|---:|---:|---:|
| Centre shuttle | C0 C1 C2 C3 C4, then reverse | 3 safety AGVs | 2.5 m/s | 100 B / 40 ms |
| Loop NW | A2 A3 A4 B4 B3 B2 A2 | 2 standard AGVs | 1.5 m/s | 100 B / 125 ms |
| Loop SE | E2 E1 E0 D0 D1 D2 E2 | 2 standard AGVs | 1.5 m/s | 100 B / 125 ms |
| Workcell | parked at (35,12), (40,12), (45,12) | 3 arm UEs | static | 100 B / 400 ms |

Every UE uses DSCP/QFI 7 and uplink FRER replication across the two independent
cellular legs; the replica is internally bound to DSCP/QFI 8. Recovery uses the
bring-up setting H=4 and a 250 ms reset timeout. The config includes the stated
3.5 GHz carrier, 25 PRBs, numerology 1, indoor-hotspot fading/shadowing, DRR UL,
one HARQ retransmission and target BLER 0.3. The baseline intentionally disables
synthetic interference so SUMO + FRER can be validated independently. Select
`AgvFleetUplinkFrerWithBackground` to add the buildsheet's eight UL interferers
at 87 m. Section 05 erasure injection is intentionally not implemented yet.

The simulation runs for 620 s total: a 20 s warm-up followed by the requested
600 s recorded measurement interval. The configuration expands
`fleetSeed=3400..3409`, producing ten runs. SUMO's
`random_free` departure positions use the matching seed while retaining the
required 3/2/2/3 regional split.

Veins performs the SUMO-to-OMNeT++ Y-axis conversion itself. The display layer
does not invert Y again, so the NW and SE loops remain in their named areas and
the three parked arm UEs remain inside the workcell. The 1 m TraCI margin also
absorbs generated lane coordinates such as `100.01` without changing the
logical 0..100 m floor plan.

The generated SUMO network also contains two unused 0.1 m padding edges at
`(-1,-1)` and `(101,101)`. No vehicle can enter them; they only ensure that
real lanes are strictly inside the TraCI boundary, avoiding Veins' rejection
of floating-point positions displayed as `-0.00`.

Veins' early deletion of managed vehicles is disabled for this demo. The
dual-connectivity NIC owns bearer submodules created at runtime; letting
OMNeT++ perform its normal network-wide finish pass avoids deleting those
submodules while `NrNicUeDC` is being enumerated.

The moving routes deliberately extend well past 620 s. SUMO shortens lane
lengths around junction interiors, so multiplying the 25 m drawing grid by the
number of edges underestimates how many route repetitions are needed. The
network-generation script now runs a 620 s SUMO-only validation and fails if
any of the ten UEs arrives before the OMNeT++ horizon.

## Run

From the repository root, with OMNeT++, INET, Simu5G, Veins and SUMO available:

```sh
./bin/agv_fleet_frer_test.sh
```

Results are written under `simulations/demos/agv_fleet_frer/results/<seed>/`.
