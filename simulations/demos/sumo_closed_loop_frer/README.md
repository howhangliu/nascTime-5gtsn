# SUMO closed-loop uplink FRER demo

This demo models a 100 m x 100 m industrial service area with two gNBs at
opposite corners and ten SUMO vehicles moving over a 3 x 3 road grid. Each
vehicle contains a TSN position source, DS-TT, and dual-connectivity NR UE.

Every source emits one 20-byte report every 10 ms. The payload fields are five
network-byte-order 32-bit values: sequence number, vehicle index, X position
(mm), Y position (mm), and speed (mm/s). DSCP 7 packets are replicated by the
vehicle DS-TT; the DSCP 8 copy is routed over the second NR stack/gNB/UPF. The
NW-TT eliminates duplicates before the report reaches `tsnServer` UDP port
7000. A dynamic configurator refreshes INET routes/addresses whenever Veins
adds a car and maps each embedded TSN source to that car's Simu5G node ID.

## Run on the Linux server

From the nascTime repository root, make sure OMNeT++, INET, Simu5G, Veins,
SUMO, and `netconvert` are available, then run:

```sh
./bin/sumo_closed_loop_frer_test.sh
```

The script regenerates the SUMO network, validates its routes, starts
`veins_launchd`, rebuilds nascTime, runs the 30-second Cmdenv simulation, and
checks the complete data path: ten reporters, no source-routing or UE Ethernet
address drops, primary and replica FRER transmission, duplicate elimination at
the NW-TT, and delivery to the TSN server.

Results are written to `simulations/demos/sumo_closed_loop_frer/results/`.
