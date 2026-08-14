# Uplink SINR Failover AoI Scenario

`UplinkSinrFailoverAoI` measures how uplink radio degradation and an
active-to-standby path switch affect Age of Information (AoI).

## Scenario behavior

The simulation lasts three seconds and sends traffic from `tsnDeviceB` to
`tsnDeviceA` through the 5G-TSN bridge:

| Simulation time | Behavior |
|---|---|
| 0–1 s | Traffic uses healthy `dsTt[0]` / `ue[0]`. |
| 1–2 s | A 12 dB uplink SINR penalty is applied to UE 0. |
| 2–3 s | The route switches to healthy standby `dsTt[1]` / `ue[1]`. |

The SINR penalty remains on UE 0 after the switch. Consequently, an AoI
recovery after 2 seconds is caused by path switching, not by restoration of
the original channel.

`TunableNrChannelModel.impairedNodeId` limits the runtime impairment to one
UE. The value `2049` used by this scenario is UE 0's Simu5G MAC node ID. UE 1
therefore remains a healthy standby while both UEs use the same gNodeB.

The scenario uses perfect simulation-time synchronization to isolate network
delivery effects from clock-synchronization error. Stream 0 is the primary
AoI stream: it sends a 100-byte UDP update every 1 ms with DSCP 6.

## Build and run in the OMNeT++ IDE

The scenario changes C++ and NED files, so rebuild `nascTime` before its first
run. INET and Simu5G must already be built, and `nascTime` must reference both
projects.

1. Refresh the `nascTime` project with **F5**.
2. Select **Project → Clean…** and clean `nascTime`.
3. Right-click `nascTime` and select **Build Project**.
4. Open `simulations/demos/uplink_test/omnetpp_uplink.ini`.
5. Select the `UplinkSinrFailoverAoI` configuration and run it to completion.

Results are written under `results/uplink/`. A typical vector filename is:

```text
results/uplink/UplinkSinrFailoverAoI-#0.vec
```

The repetition number may be different if multiple runs are retained.

## Generate the AoI plot

The analyzer requires Python 3 and Matplotlib. Install Matplotlib if needed:

```bash
python3 -m pip install matplotlib
```

From `simulations/demos/uplink_test`, analyze the primary periodic stream:

```bash
python3 analyze_aoi.py \
  "results/uplink/UplinkSinrFailoverAoI-#0.vec" \
  --stream 0 \
  --bad-at 1 \
  --switch-at 2 \
  --max-time 3
```

Use `--stream 1` for the best-effort stream. The script creates:

```text
UplinkSinrFailoverAoI-#0-aoi-stream0.png
UplinkSinrFailoverAoI-#0-aoi-stream0.peaks.csv
```

It also prints the number of received updates and the mean and maximum peak
AoI. The CSV retains the peak measurements even though peak markers are not
drawn on the plot.

## AoI calculation

Age of Information at time `t` is

```text
AoI(t) = t - u(t)
```

where `u(t)` is the generation time of the freshest update received so far.
For packet `i`, INET records its reception time `r_i` and end-to-end delay
`d_i`, so the analyzer reconstructs its generation time as

```text
g_i = r_i - d_i
```

Immediately after packet `i` arrives, AoI resets to `r_i - g_i = d_i`.
Between receptions it increases linearly. Immediately before the next fresh
packet arrives, peak AoI is

```text
peak_i = r_(i+1) - g_i
```

Stale or reordered packets whose generation time is not newer than the latest
accepted update do not reset AoI.

The shaded red interval in the plot is the degraded-primary period. The green
interval begins when traffic switches to the standby path. Higher sustained
AoI or tall spikes indicate that the receiver waited longer for fresh data,
for example because of scheduling delay, HARQ retransmission, queueing, or
packet loss.
