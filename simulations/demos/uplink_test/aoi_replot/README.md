# Replotting the UplinkSinrFailoverAoI AoI and PAoI figures

Self-contained copy of the raw data and the plotting code behind

```text
UplinkSinrFailoverAoI-#0-aoi-stream0.png     # the AoI sawtooth
UplinkSinrFailoverAoI-#0-paoi-stream0.png    # peak AoI against simulation time
```

Nothing here imports from the rest of the repository, and OMNeT++ is not
needed to replot. The only dependency is Matplotlib:

```bash
python3 -m pip install matplotlib
```

## Replot

From this directory:

```bash
python3 plot_aoi.py
```

Useful variations:

| Command | Effect |
|---|---|
| `python3 plot_aoi.py --mode paoi` | peak AoI against simulation time |
| `python3 plot_aoi.py --mode paoi --window 50` | the same, with a 50-sample running mean |
| `python3 plot_aoi.py --mode both` | the sawtooth with its peaks marked |
| `python3 plot_aoi.py --stream 1` | the best-effort stream instead of the periodic one |
| `python3 plot_aoi.py --output figure.pdf` | vector output; the suffix picks the format |
| `python3 plot_aoi.py --from-vec` | re-derive everything from the raw `.vec` rather than the CSV |

## AoI or PAoI?

`--mode aoi` draws the continuous sawtooth: age climbing at 45 degrees between
receptions and dropping to the packet's end-to-end delay on each arrival. It
shows what the age actually was at every instant.

`--mode paoi` draws only the tip of each ramp -- one point per reception,
which is the worst age reached before that packet refreshed the receiver.
Those points are the PAoI samples, and they are what the CCDF and the
mean/max statistics are computed from. They are drawn as markers rather than a
line on purpose: peak AoI has no value between receptions, so joining the
points would invent one.

With ~1000 receptions per second the raw PAoI scatter is dense, so
`--window N` overlays a running mean over N consecutive samples -- at this
rate `--window 50` smooths over roughly 50 ms and makes the phase contrast
obvious.

`--from-vec` and the default CSV path produce byte-identical figures; the CSV
is simply the faster of the two.

Colours, figure size, DPI, the phase boundaries and the axis limits are
constants in the `STYLE` block at the top of `plot_aoi.py`.

## Files

| File | Contents |
|---|---|
| `plot_aoi.py` | the plotting code, standalone |
| `data/UplinkSinrFailoverAoI-#0.vec` | raw OMNeT++ vector output of the run |
| `data/aoi_timeline_stream{0,1}.csv` | `time_s, aoi_ms` — exactly the plotted sample path |
| `data/receptions_stream{0,1}.csv` | `recv_time_s, end_to_end_delay_s, generation_time_s, seq_no` — per-packet source data |
| `data/peaks_stream{0,1}.csv` | `time_s, peak_aoi_s, peak_aoi_ms, recv_seq_no` — the PAoI samples |

`receptions_*.csv` is the real source: everything else is derived from it, so
start there if you want to compute something other than AoI.

## The run this came from

`[Config UplinkSinrFailoverAoI]` in `../omnetpp_uplink.ini`, 3 s of simulation
with perfect time synchronization, regenerated on 2026-08-18. The run is
seeded (`seedset 0`), so re-running reproduces these numbers exactly.

| Simulation time | Behaviour |
|---|---|
| 0–1 s | traffic on the healthy `dsTt[0]` / `ue[0]` leg |
| 1–2 s | 12 dB uplink SINR penalty on UE 0 (red band) |
| 2–3 s | route switched to the healthy standby `ue[1]` (green band) |

The penalty stays on UE 0 after the switch, so the recovery at 2 s is caused
by the path change, not by the channel healing.

Stream 0 is the primary AoI stream: a 100-byte UDP update every 1 ms with
DSCP 6. Stream 1 is best effort.

Peak AoI for stream 0, by phase:

| Phase | n | mean | max |
|---|---|---|---|
| 0–1 s baseline | 975 | 13.83 ms | 58.16 ms |
| 1–2 s degraded | 784 | 33.87 ms | 49.67 ms |
| 2–3 s standby | 993 | 14.53 ms | 56.16 ms |
| whole run | 2752 | 19.79 ms | 58.16 ms |

## AoI definition

`AoI(t) = t - u(t)`, where `u(t)` is the generation time of the freshest
update received so far. INET records each packet's reception time `r` and its
end-to-end delay `d`, so its generation time is `u = r - d`. AoI therefore
drops to `d` on arrival and climbs at 45 degrees between arrivals. Peak AoI
before the arrival of packet `i+1` is `r_(i+1) - u_i`. A stale or reordered
packet carries no newer information, so it does not reset the age — it widens
the following peak instead of producing one of its own.

## Regenerating the data after a new run

The `paoi` package under `simulations/analysis` and the `analyze_aoi.py` front
end in the parent directory produce the same numbers from a fresh `.vec`.
Alternatively, point this script straight at a new result file:

```bash
python3 plot_aoi.py --from-vec --vec /path/to/UplinkSinrFailoverAoI-#0.vec
```
