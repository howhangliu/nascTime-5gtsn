# SUMO-backed moving NR UE

This is the smallest SUMO/Veins baseline in nascTime. SUMO creates one vehicle
on a 1 km straight road; `VeinsInetManager` creates `car[0]` as a Simu5G
`NrCar`; the car sends UDP traffic through one gNB to a fixed server.

The run also writes `results/mobility.csv` at 100 ms intervals. This trace is
the stable input intended for later site-specific channel providers.

## Dependencies

- OMNeT++ 6.4.0
- INET 4.6.0
- the workspace Simu5G build
- Veins 5.3.1 plus its `veins_inet` subproject
- Eclipse SUMO 1.22.0 (TraCI API 21, the newest API supported by Veins 5.3.1)

`sumo` and `netconvert` must be on `PATH`. SUMO 1.23 and newer use TraCI API
22, which Veins 5.3.1 does not support. On a supported host, install the pinned
version in a virtual environment with
`python -m pip install eclipse-sumo==1.22.0`, then activate it before the run.

Veins is kept as a sibling project, like INET and Simu5G. On the Linux host
that owns the existing OMNeT++ build, enter the same `opp_env` shell (so
`opp_makemake`, `INET_ROOT`, and `SIMU5G_ROOT` are available), then configure
it as follows:

```sh
cd /path/to/workspace/veins
./configure
make -j

cd subprojects/veins_inet
./configure --with-veins=../.. --with-inet=../../../inet
make -j

cd ../../../nascTime
make -j
```

The current workspace has Veins 5.3.1 checked out at `../veins`. Build all
three libraries with the same compiler and platform as OMNeT++.

## Run

From this directory:

```sh
../../../bin/sumo_nr_smoke_test.sh
```

The script generates `straight.net.xml`, starts `veins_launchd`, runs the
scenario in Cmdenv, stops the launcher, and checks both UDP reception and the
mobility CSV.

The existing `UplinkBadRadio` configuration remains useful as a lightweight
moving-UE test without SUMO. This scenario is specifically for validating the
SUMO -> Veins -> Simu5G synchronization path.
