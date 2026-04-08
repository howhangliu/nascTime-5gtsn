<p align='center'>
  <img width="430" height="146" alt="upscaled_logo-removebg-preview" src="https://github.com/user-attachments/assets/76eb2f68-5924-402b-936e-5ec78fc352d0" />
</p>

# nascTime (5G-TSN Bridge)

## Overview

This package implements the 3GPP Release 16 5G-TSN integration bridge model
(TS 23.501 §5.28) for the OMNeT++ / INET / Simu5G simulation stack. The 5G
system acts as a transparent IEEE 802.1AS-compliant bridge between two TSN
network segments, with full QoS mapping, CNC-style configuration, static
BMCA clock hierarchy, multi-endpoint scaling, and LayeredEthernetInterface
with streaming PHY for TSN feature compatibility.

**Stack:** OMNeT++ 6.3 · INET 4.6.x · Simu5G v1.4.1-sdap-2 (SDAP branch, UCC)

**End-to-end path (multi-endpoint):**
```
                                                    UE[0] → DS-TT[0] → TSN Device B[0]
TSN Device A → TsnSwitch → NW-TT → UPF → gNB ────   UE[1] → DS-TT[1] → TSN Device B[1]
                                                    UE[2] → DS-TT[2] → TSN Device B[2]
```

**Validated results (3-endpoint, 10s simulation, bidirectional):**

| Direction | Endpoint 0 | Endpoint 1 | Endpoint 2 |
|-----------|-----------|-----------|-----------|
| Forward high priority | 9990 | 9993 | 9993 |
| Forward best effort | 5020 | 5122 | 5101 |
| Reverse (to Device A) | 800 | 800 | 800 |
| gPTP forwarded | 158 | 158 | 158 |

- Device A received 2400 reverse packets (800 × 3 endpoints)
- 5GS residence time: min=2499.756µs, max=2499.948µs, avg=2499.852µs
- QoS: PCP=6 → DSCP=6 → QFI=6 → DRB 1 per endpoint
- TSN AF: 6 stream reservations, live delay tracking
- Static BMCA: 6-node hierarchy validated, 0 errors
- All bridge ports use LayeredEthernetInterface with EthernetStreamingPhyLayer

---

## License & Citation

### License

This project is licensed under the GNU Lesser General Public License v3.0 (LGPL-3.0).

You are free to use, modify, and distribute this software in both open-source and proprietary applications, provided that any modifications to the library itself remain open and users retain the ability to relink against modified versions.

For full details, see the LICENSE file or visit the official page by the Free Software Foundation.

### Support the Project

If you find this repository useful for your research or development, please consider giving it a ⭐ on GitHub, it helps increase visibility and supports continued development.

### Citation

If you use this work in your research, please cite:

```bibtex
@article{nasctime2026,
  title   = {nascTime: A Full-Stack 5G-TSN Bridge Simulation Framework with SDAP-Based QoS Mapping and IEEE 802.1AS Transparent Clock},
  author  = {Mohamed Seliem, Utz Roedig, Cormac Sreenan, Dirk Pesch},
  journal = {arXiv preprint arXiv:2604.04616},
  year    = {2026}
}
```

### Paper
<a href= "https://arxiv.org/abs/2604.04616"> nascTime Draft</a> (Final version will appear in a conference proceeding)

---

## Completed Features

| Gap | Description | Status |
|-----|-------------|--------|
| G1  | NW-TT and DS-TT bridge port modules | ✅ Complete |
| G2  | gPTP tunnel transport (sideband + L2-in-GTP-U) | ✅ Complete |
| G3  | Residence time correction (transparent clock) | ✅ Complete |
| G4  | QoS mapping (PCP ↔ 5QI) with SDAP DRB selection | ✅ Complete |
| G5  | TSN AF / CNC configuration | ✅ Complete |
| G6  | Static BMCA (clock hierarchy management) | ✅ Complete |


| Hardening | Description | Status |
|-----------|-------------|--------|
| H1 | Dynamic pppIf interface ID lookup | ✅ Complete |
| H2 | DS-TT unicast MAC address resolution | ✅ Complete |
| H3 | NW-TT egress path (bidirectional traffic) | ✅ Complete |
| H4 | Robust gPTP message type handling | ✅ Complete |
| H5 | LayeredEthernetInterface with streaming PHY | ✅ Complete |
| H6 | VLAN tag preservation for passthrough traffic | ✅ Complete |

| Scaling | Description | Status |
|---------|-------------|--------|
| S1 | Multi-destination binder registration | ✅ Complete |
| S2 | Scalable parameterized network NED | ✅ Complete |
| S3 | Per-endpoint IP addressing | ✅ Complete |
| S4 | Per-endpoint SDAP/DRB configuration | ✅ Complete |
| S5 | Per-endpoint gPTP configuration | ✅ Complete |
| S6 | gPTP multi-destination replication | ✅ Complete |
| S7 | Multi-endpoint traffic configuration | ✅ Complete |
| S8 | Integration test (bidirectional, 3 endpoints) | ✅ Complete |

---

## Architecture

### NW-TT (Network-side TSN Translator)

**Module:** `NwTt extends NetworkLayerNodeBase`

The NW-TT is the ingress bridge port (TS 23.501 §5.28.3). It connects the
external TSN network to the UPF.

```
                    NwTt compound module
            ┌──────────────────────────────────────┐
            │                                      │
            │  LayeredEthernetInterface (ethIf)     │
            │  [EthernetStreamingPhyLayer]          │
TSN Switch ◄──►    │                               │
            │      ▼                               │
            │  ethLi (MessageDispatcher)            │
            │      │                               │
            │      ├──► NwTtTranslator (ingress)   │
            │      │    ├─ Data: strip Eth + VLAN, │
            │      │    │  read PCP, set DSCP,     │
            │      │    │  forward to pppIf        │
            │      │    └─ gPTP: detect 0x88F7,    │
            │      │       replicate to endpoints, │
            │      │       L2-in-GTP-U transport   │
            │      │                               │
            │      └──► EthernetEncapsulation       │
            │           (egress: 5GS → TSN)        │
            │              │                       │
            │  PppInterface (pppIf) ──────────────►│◄──► UPF
            └──────────────────────────────────────┘
```

**Key design decisions:**
- Extends `NetworkLayerNodeBase` (same pattern as `Upf.ned`)
- `ethIf` uses `LayeredEthernetInterface` with `EthernetStreamingPhyLayer` (H5)
- `ethLi` MessageDispatcher routes between `ethIf`, translator, and `encap`
- `serviceMapping = {"ethernetmac": "ethIf"}` on `ethLi` for egress routing
- Asymmetric paths: ingress through translator, egress through `encap`
- `encap.registerProtocol = false` to avoid dispatcher conflicts; service
  registered manually on `nl` for IPv4 egress routing
- gPTP frames replicated to all registered downstream devices (S6)
- Dynamic pppIf interface ID lookup via InterfaceTable (H1)

### DS-TT (Device-side TSN Translator)

**Module:** `DsTt` (standalone two-port L2 bridge)

The DS-TT is the egress bridge port (TS 23.501 §5.28.4).

```
            DsTt compound module
    ┌─────────────────────────────────────────┐
    │                                         │
    │  LayeredEthernetInterface (ueEth)       │
    │  [EthernetPhyLayer — non-streaming]     │
UE ◄──►    │                                  │
    │      ▼                                  │
    │  ueLi (MessageDispatcher)               │
    │      │                                  │
    │      ▼                                  │
    │  DsTtTranslator                         │
    │   ├─ Data: strip/rebuild Eth frames,    │
    │   │  DSCP→PCP mapping, unicast MAC (H2) │
    │   ├─ gPTP: detect UDP:30001, unwrap,    │
    │   │  residence time + correctionField   │
    │   └─ Reverse: TSN→UE forwarding         │
    │      │                                  │
    │      ▼                                  │
    │  tsnLi (MessageDispatcher)              │
    │      │                                  │
    │      ▼                                  │
    │  LayeredEthernetInterface (tsnEth)       │
    │  [EthernetStreamingPhyLayer]            │
    │──►                                      │◄──► TSN Device B
    └─────────────────────────────────────────┘
```

**Key design decisions:**
- `tsnEth` uses streaming PHY (matches TSN Device B's streaming PHY)
- `ueEth` uses non-streaming PHY (matches UE's plain `EthernetInterface`)
- `tsnLi` and `ueLi` MessageDispatchers with `serviceMapping` for routing
- `DispatchProtocolReq` + `DirectionTag` set on outgoing packets
- FCS value `0xC00DC00D` for `LayeredEthernetInterface` compatibility
- `registerProtocol(Protocol::ethernetMac)` on both gate pairs

### TSN AF (Application Function)

**Module:** `TsnAf` (3GPP TS 23.501 §5.28.2)

```
        TSN AF
    ┌─────────────────────────────────────┐
    │  Live Bridge Monitoring             │
    │  ├─ Subscribes to DS-TT residence   │
    │  │  time signal                     │
    │  ├─ Publishes delay min/max/avg     │
    │  └─ Detects QoS violations          │
    │                                     │
    │  CNC Configuration (from XML)       │
    │  ├─ Stream reservations             │
    │  └─ TAS gate control lists          │
    │                                     │
    │  API                                │
    │  ├─ getQfiForPcp() / getPcpForQfi() │
    │  └─ getBridgeDelayMin/Max/Avg()     │
    └─────────────────────────────────────┘
```

### Static BMCA

**Module:** `StaticBmca` (IEEE 802.1AS-2020 §10.3)

```
        Static BMCA
    ┌─────────────────────────────────────┐
    │  Clock Hierarchy                    │
    │  ├─ Grandmaster: tsnDeviceA         │
    │  ├─ Bridge: tsnSwitch               │
    │  ├─ Slaves: tsnDeviceB[0..N]        │
    │  └─ Transparent clock: 5GS bridge   │
    │                                     │
    │  Topology Validation                │
    │  ├─ Single grandmaster check        │
    │  ├─ Missing role detection          │
    │  └─ CorrectionField support check   │
    │                                     │
    │  API                                │
    │  ├─ getGrandmasterInfo()            │
    │  ├─ getNodeRole(moduleName)         │
    │  └─ isTransparentClock(moduleName)  │
    └─────────────────────────────────────┘
```

### QoS Mapping Pipeline

```
TSN Device A (PCP=6 in VLAN tag)
  → NW-TT: strips 802.1Q VLAN tag, reads PCP=6, sets IPv4 DSCP=6
  → UPF TrafficFlowFilter: reads DSCP=6, sets QFI=6
  → GtpUser: carries QFI=6 in GTP-U PDU Session Container
  → gNB SDAP: reads QfiReq(6), selects DRB 1 per drbConfig
  → MAC scheduler: schedules DRB 1 with configured priority
  → UE SDAP: extracts QFI=6 from SDAP header
  → DS-TT: reads IPv4 DSCP=6, maps to PCP=6 via UserPriorityReq
  → TSN Device B receives with original priority
```

### gPTP Transport

Two modes via `*.nwTt.translator.gptpTransportMode`:

**`"gtpu"` (primary):** gPTP frames wrapped in UDP:30001, sent through actual
5GS data plane. Replicated to all registered endpoints (S6). Carries
`GptpResidenceHeader` with ingress timestamp. DS-TT computes residence time
and updates correctionField per message type (Sync/FollowUp separately, H4).

**`"sideband"` (fallback):** Direct OMNeT++ connection with configurable delay.

---

## File Inventory

### Source modules (`src/nodes/nascTime/`)

```
src/nodes/nascTime/NwTt/                 NW-TT (Network-side TSN Translator)
├── NwTt.ned                             Compound module (LayeredEthernetInterface + ethLi dispatcher)
├── NwTtTranslator.ned                   Simple module (L2↔IP + QoS + gPTP replication)
├── NwTtTranslator.h                     C++ header
├── NwTtTranslator.cc                    C++ implementation
├── GptpSideband.ned                     gPTP sideband delay module (fallback)
├── GptpSideband.h                       C++ header
├── GptpSideband.cc                      C++ implementation
└── GptpResidenceHeader.msg              Residence time header (auto-compiled)

src/nodes/nascTime/DsTt/                 DS-TT (Device-side TSN Translator) + UE variants
├── DsTt.ned                             Compound module (LayeredEthernetInterface + tsnLi/ueLi dispatchers)
├── DsTtTranslator.ned                   Simple module (L2 forwarder + gPTP + QoS)
├── DsTtTranslator.h                     C++ header
├── DsTtTranslator.cc                    C++ implementation
├── NRUeDsTt.ned                         NR UE with Ethernet port (extends NRUe)
└── NRUeDsTtDrb.ned                      NR UE DRB with Ethernet port (extends NRUeDrb)

src/nodes/nascTime/TsnAf/                TSN Application Function + BMCA
├── TsnAf.ned                            TSN AF (bridge capabilities + CNC config)
├── TsnAf.h                              C++ header
├── TsnAf.cc                             C++ implementation
├── StaticBmca.ned                       Static BMCA stub (clock hierarchy)
├── StaticBmca.h                         C++ header
└── StaticBmca.cc                        C++ implementation
```

### Simulations (`simulations/nascTime_tests/`)

```
simulations/nascTime_tests/nwtt_test/            NW-TT only baseline (G1)
├── NwTtTestNetwork.ned
├── omnetpp.ini
└── nwtt_ip_config.xml

simulations/nascTime_tests/bridge_test/          Full bridge without gPTP (G1)
├── BridgeTestNetwork.ned
├── omnetpp.ini
└── bridge_ip_config.xml

simulations/nascTime_tests/gptp_test/            Full bridge with gPTP + residence time (G2+G3)
├── GptpBridgeTestNetwork.ned
├── omnetpp.ini
└── gptp_bridge_ip_config.xml

simulations/nascTime_tests/qos_test/             QoS + TSN AF + BMCA (G4+G5+G6)
├── QosBridgeTestNetwork.ned
├── omnetpp.ini
├── qos_bridge_ip_config.xml
└── cnc_config.xml

simulations/nascTime_tests/multi_endpoint_test/  Multi-endpoint scaling (S1-S8)
├── MultiEndpointNetwork.ned
├── omnetpp.ini
├── multi_ip_config.xml
└── cnc_config.xml
```

---

## H5: LayeredEthernetInterface Migration

The NW-TT and DS-TT bridge ports use `LayeredEthernetInterface` with
`EthernetStreamingPhyLayer` for compatibility with TSN features (TAS,
frame preemption, gPTP peer delay measurement).

### Key technical decisions

**Problem:** `LayeredEthernetInterface` extends `NetworkInterface` which uses
`pushPacket()` internally. Direct connection to a plain `cSimpleModule`
(our translators) breaks the gate chain.

**Solution:** `MessageDispatcher` modules (`ethLi`, `tsnLi`, `ueLi`) sit
between each `LayeredEthernetInterface` and the translator. The dispatchers
route packets using protocol registration and `serviceMapping`.

**NW-TT `encap` conflict:** `EthernetEncapsulation` with `registerProtocol=true`
propagates its registration through ALL connected dispatchers, including `ethLi`.
This conflicts with `ethIf`'s own registration. Fix: set `registerProtocol=false`
and manually register the service on `nl` from the translator's `initialize()`.

**PHY asymmetry in DS-TT:** `tsnEth` uses streaming PHY (faces Device B which
also uses streaming). `ueEth` uses non-streaming `EthernetPhyLayer` (faces the
UE's plain `EthernetInterface` with `EthernetMacPhy`).

**Packet tags:** Outgoing packets from the translator to `LayeredEthernetInterface`
require `DispatchProtocolReq`, `DirectionTag(DIRECTION_OUTBOUND)`, and
`PacketProtocolTag(Protocol::ethernetMac)`. FCS must use value `0xC00DC00D`.

---

## Configuration Reference

### Essential .ini parameters

```ini
simtime-resolution = fs
**.arp.typename = "GlobalArp"
*.configurator.addStaticRoutes = true

# NW-TT
*.nwTt.translator.ueAddress = "ue[0]"
*.nwTt.translator.localAddress = "nwTt"
*.nwTt.translator.gptpTransportMode = "gtpu"
*.nwTt.translator.gptpEncapUdpPort = 30001
*.nwTt.ethIf.bitrate = 1Gbps

# NW-TT multi-endpoint registration
*.nwTt.translator.tsnDeviceBAddresses = [ \
    {address: "tsnDeviceB[0]", ue: "ue[0]"}, \
    {address: "tsnDeviceB[1]", ue: "ue[1]"}, \
    {address: "tsnDeviceB[2]", ue: "ue[2]"}]

# UE
*.ue[*].masterId = 0
*.ue[*].nrMacCellId = 1
*.ue[*].nrMasterId = 1
*.ue[*].ipv4.forwarding = true

# H5: All TSN nodes use LayeredEthernetInterface with streaming PHY
*.tsnDeviceA.eth[*].typename = "LayeredEthernetInterface"
*.tsnDeviceA.eth[*].phyLayer.typename = "EthernetStreamingPhyLayer"
*.tsnSwitch.eth[*].typename = "LayeredEthernetInterface"
*.tsnSwitch.eth[*].phyLayer.typename = "EthernetStreamingPhyLayer"
*.tsnDeviceB[*].eth[*].typename = "LayeredEthernetInterface"
*.tsnDeviceB[*].eth[*].phyLayer.typename = "EthernetStreamingPhyLayer"
```

### SDAP / DRB configuration

```ini
*.gnb.cellularNic.numDrbs = 2
*.gnb.cellularNic.sdap.drbConfig = [ \
    {drb: 0, ue: 2049, qfiList: [0]}, {drb: 1, ue: 2049, qfiList: [6]}, \
    {drb: 0, ue: 2050, qfiList: [0]}, {drb: 1, ue: 2050, qfiList: [6]}, \
    {drb: 0, ue: 2051, qfiList: [0]}, {drb: 1, ue: 2051, qfiList: [6]}]

*.ue[*].cellularNic.numDrbs = 2
*.ue[*].cellularNic.sdap.drbConfig = [{drb: 0, qfiList: [0]}, {drb: 1, qfiList: [6]}]
```

### gPTP configuration

```ini
*.tsnDeviceA.hasTimeSynchronization = true
*.tsnDeviceA.gptp.gptpNodeType = "MASTER_NODE"
*.tsnDeviceA.gptp.masterPorts = ["eth0"]
*.tsnDeviceA.gptp.slavePort = ""

*.tsnDeviceB[*].hasTimeSynchronization = true
*.tsnDeviceB[*].gptp.gptpNodeType = "SLAVE_NODE"
*.tsnDeviceB[*].gptp.slavePort = "eth0"
*.tsnDeviceB[*].gptp.masterPorts = []
```

### IP addressing scheme

```
10.0.0.0/24       TSN domain A (tsnDeviceA, tsnSwitch, nwTt.ethIf)
10.0.1.0/24       NW-TT ↔ UPF link
10.0.2.0/24       UPF ↔ gNB link
10.0.3.0/24       Cellular (gNB ↔ UEs)
192.168.1.0/24    UE[0] ↔ DS-TT[0] ↔ TSN Device B[0]
192.168.2.0/24    UE[1] ↔ DS-TT[1] ↔ TSN Device B[1]
192.168.3.0/24    UE[2] ↔ DS-TT[2] ↔ TSN Device B[2]
```

---

## Simu5G Source Modifications

The following Simu5G source files require modification for multi-UE DRB support:

**`src/stack/NRNicEnbDrb.ned`:**
- `nrPdcp[numDrbs].multiSession`: changed from `false` to `default(true)`
- `nrRlc[numDrbs].um.multiSession`: changed from `false` to `default(true)`

---

## Build Instructions

### Prerequisites
- OMNeT++ 6.3 installed and in PATH
- INET 4.6.x built
- Simu5G v1.4.1-sdap-2 built (with `multiSession` modifications above)

### Integration

1. Copy `src/nodes/nascTime/` into your Simu5G source tree under `src/nodes/`.
2. Copy `simulations/nascTime_tests/` into your Simu5G simulations tree.
3. Apply the `NRNicEnbDrb.ned` modifications (multiSession = true).
4. Rebuild Simu5G:
   ```bash
   cd <simu5g>/src
   make -j$(nproc)
   ```
5. Run:
   ```bash
   cd <simu5g>/simulations/nascTime_tests/multi_endpoint_test
   opp_run -u Cmdenv -c MultiEndpointTest -f omnetpp.ini \
     -n ".:../../src:<inet>/src" \
     -l ../../src/simu5g -l <inet>/src/INET
   ```

---

## Known Limitations

1. **TSN AF TAS gate control** parsed and logged but not programmatically
   applied to TSN Device A's `Ieee8021qTimeAwareShaper`.

2. **Static BMCA** validates topology but does not dynamically reconfigure
   gPTP port roles. INET's `Gptp` module does not support dynamic BMCA.

---

## References

- 3GPP TS 23.501 §5.28 — 5G-TSN integration architecture
- 3GPP TS 23.501 §5.28.2 — TSN Application Function (TSN AF)
- 3GPP TS 23.501 §5.28.3 — NW-TT functionality
- 3GPP TS 23.501 §5.28.4 — DS-TT functionality
- 3GPP TS 29.281 §5.2.1 — GTP-U PDU Session Container
- IEEE 802.1AS-2020 — Timing and Synchronization for TSN
- IEEE 802.1AS-2020 §10.3 — Best Master Clock Algorithm (BMCA)
- IEEE 802.1AS-2020 §11.2.14.2.3 — Transparent clock correction
- IEEE 802.1Q — VLAN tagging and Priority Code Point (PCP)
- IEEE 802.1Qbv — Time-Aware Shaping (TAS) gate control
