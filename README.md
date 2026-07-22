<p align='center'>
  <img width="430" height="146" alt="upscaled_logo-removebg-preview" src="https://github.com/user-attachments/assets/76eb2f68-5924-402b-936e-5ec78fc352d0" />
</p>

# nascTime (5G-TSN Bridge)

## Overview

This package implements the 3GPP Release 16 5G-TSN integration bridge model
(TS 23.501 §5.28) for the OMNeT++ / INET / Simu5G simulation stack. The 5G
system acts as a transparent IEEE 802.1AS-compliant bridge between two TSN
network segments, with full QoS mapping, CNC-style configuration, static
BMCA clock hierarchy, multi-endpoint scaling, LayeredEthernetInterface
with streaming PHY for TSN feature compatibility, and IEEE 802.1CB Frame
Replication and Elimination for Reliability (FRER) across configurable
transport-diversity paths.

**Stack:** OMNeT++ 6.3 · INET 4.6.x · Simu5G v1.5.0

nascTime is a standalone OMNeT++ project. It does not require any source
modifications to Simu5G — it references INET and Simu5G as sibling
projects and builds against their published module APIs, including
Simu5G's native SDAP/DRB support.

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

Figures above were measured on the Simu5G v1.4.1-sdap-2 stack referenced in
the paper below. The same scenario has since been confirmed to run cleanly
on Simu5G v1.5.0 with consistent delivery behavior; the v1.5.0 build is now
the primary supported target for this repository.

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

| FRER (IEEE 802.1CB) | Description | Status |
|---------|-------------|--------|
| F1 | Stream replication and DSCP-based recovery, single N3 path (DRB-level transport diversity only) | ✅ Complete |
| F2 | Uplink replication/recovery (device → network) | ✅ Complete |
| F3 | Inter-PDU-session transport diversity (independent N3 paths through two UPFs to the same gNB) | 🔶 Implemented, integration testing in progress |
| F4 | NR dual-connectivity transport diversity (independent gNBs, independent radio channels) | 🔷 In development |

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
- PCP→DSCP translation is configurable via `mappedPcpValues` (default maps
  all PCP 0–7)

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
- `ueEth` uses non-streaming `EthernetPhyLayer` (faces the UE's plain
  `EthernetInterface` with `EthernetMacPhy`)
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

Set `gptpTransportMode` explicitly in your scenario's `.ini` file — don't
rely on its default.

### IEEE 802.1CB FRER (Frame Replication and Elimination for Reliability)

**Modules:** `FrerReplicator`, `FrerRecovery`

FRER duplicates selected traffic streams at the network edge and
eliminates duplicates at the receiving edge, providing seamless
redundancy without relying on retransmission. In nascTime, replication
happens at the NW-TT (downlink) or DS-TT (uplink), and recovery happens
at the corresponding opposite end.

```
        FrerReplicator                        FrerRecovery
    ┌─────────────────────┐               ┌─────────────────────┐
    │  Eligible streams    │               │  Sequence-window     │
    │  selected by DSCP    │               │  duplicate            │
    │  (frerStreams)        │──── primary ─►│  elimination          │
    │                       │──── replica ─►│  (windowSize,         │
    │  Replica gets its own │               │  windowTimeout)       │
    │  DSCP (replicaDscp)   │               │                       │
    │  and, for path-diverse│               │  Non-FRER streams     │
    │  bindings, a distinct │               │  pass through          │
    │  egress interface     │               │  untouched             │
    └─────────────────────┘               └─────────────────────┘
```

**Transport bindings** (`transportBinding` parameter) control how the
replica is made physically or logically distinct from the primary:

| Binding | Replica path | Diversity |
|---|---|---|
| `drb` | Same N3 path, different DRB/QFI | QoS-level separation only |
| `pduSession` | Independent N3 path, same gNB | Independent PDCP/RLC + independent core-network path |
| `dualConnectivity` | Independent N3 path, independent gNB | Full radio-path diversity — uncorrelated radio-level failures |

Key parameters (set on `nwTt.frerReplicator`/`dsTt[*].frerRecovery` or
their uplink counterparts):

```ini
*.nwTt.frerEnabled = true
*.nwTt.frerReplicator.frerStreams = "7"        # comma-separated DSCP values to replicate
*.nwTt.frerReplicator.replicaDscp = 8          # DSCP assigned to the replica
*.nwTt.frerReplicator.transportBinding = "drb" # "drb" | "pduSession" | "dualConnectivity"

*.dsTt[*].frerEnabled = true
*.dsTt[*].frerRecovery.frerStreams = "7"
*.dsTt[*].frerRecovery.replicaDscp = 8
*.dsTt[*].frerRecovery.windowSize = 64
*.dsTt[*].frerRecovery.windowTimeout = 0.1s
```

For `pduSession` and `dualConnectivity` bindings, also set
`replicaInterface` to the name of the secondary PPP interface (see
`NascGNodeB` below) and configure a second UPF (and, for
`dualConnectivity`, a second gNB) in your topology.

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
├── NRUeDsTt.ned                         NR UE with Ethernet port (extends NrNicUe)
└── NRUeDsTtDrb.ned                      NR UE with Ethernet port + multi-DRB QoS

src/nodes/nascTime/TsnAf/                TSN Application Function + BMCA
├── TsnAf.ned                            TSN AF (bridge capabilities + CNC config)
├── TsnAf.h                              C++ header
├── TsnAf.cc                             C++ implementation
├── StaticBmca.ned                       Static BMCA stub (clock hierarchy)
├── StaticBmca.h                         C++ header
└── StaticBmca.cc                        C++ implementation

src/nodes/frer/                          IEEE 802.1CB FRER framework
├── IFrerTransportBinding.h              Abstract transport-binding interface
├── FrerReplicator.ned / .h / .cc        Stream replication (DL at NW-TT, UL at DS-TT)
├── FrerRecovery.ned / .h / .cc          Duplicate elimination (DL at DS-TT, UL at NW-TT)
├── DrbTransportBinding.h                DRB-level replica separation (same N3 path)
├── PathDiverseTransportBinding.h        Shared base for path-diverse bindings
├── PduSessionTransportBinding.h         Independent N3 path, same gNB
└── DualConnTransportBinding.h           Independent N3 path, independent gNB

src/nodes/nascTime/NascGNodeB.ned        gNB extension with a second PPP interface (ppp2) for
                                          FRER inter-session / dual-connectivity transport
                                          diversity
```

### Simulations (`simulations/demos/`) and Tests (`tests/`)

```
tests/nwtt_test/            NW-TT only baseline (G1)
├── NwTtTestNetwork.ned
├── omnetpp.ini
└── nwtt_ip_config.xml

tests/bridge_test/          Full bridge without gPTP (G1)
├── BridgeTestNetwork.ned
├── omnetpp.ini
└── bridge_ip_config.xml

tests/gptp_test/            Full bridge with gPTP + residence time (G2+G3)
├── GptpBridgeTestNetwork.ned
├── omnetpp.ini
└── gptp_bridge_ip_config.xml

tests/qos_test/             QoS + TSN AF + BMCA (G4+G5+G6)
├── QosBridgeTestNetwork.ned
├── omnetpp.ini
├── qos_bridge_ip_config.xml
└── cnc_config.xml

simulations/demos/multi_endpoint_test/  Multi-endpoint scaling (S1-S8)
├── MultiEndpointNetwork.ned
├── omnetpp.ini
├── multi_ip_config.xml
└── cnc_config.xml

simulations/demos/ext_multiendpoint_test/  Scalability sweep, heterogeneous traffic mix
├── ExtendedMultiEndpointNetwork.ned
├── ex_multi_omnetpp.ini
├── gen_profile_ini.py                   Generates per-N traffic profile fragments
└── profiles/

simulations/demos/frer_test/            FRER validation (F1-F4)
├── frer_uplink.ini                      Uplink replication/recovery
├── frer_intersession.ini                Inter-PDU-session transport diversity
├── frer_dualconn.ini                    NR dual-connectivity transport diversity
├── frer_sweep.ini                       Scheduler × N × FRER-mode evaluation sweep
├── gen_profile_ini.py                   FRER-extended traffic profile generator
└── profiles/
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
*.ue[*].servingNodeId = 0
*.ue[*].nrServingNodeId = 1
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

SDAP is enabled per NIC via `hasSdap`, and DRB routing is configured with a
JSON-style `drbConfig` list mapping QFIs to DRB indices:

```ini
*.gnb.cellularNic.hasSdap = true
*.ue[*].cellularNic.hasSdap = true

*.gnb.cellularNic.sdap.drbConfig = [ \
    {"drb": 0, "ue": 2049, "qfiList": [0], "rlcType": "UM"}, \
    {"drb": 1, "ue": 2049, "qfiList": [6], "rlcType": "UM"}, \
    {"drb": 0, "ue": 2050, "qfiList": [0], "rlcType": "UM"}, \
    {"drb": 1, "ue": 2050, "qfiList": [6], "rlcType": "UM"}, \
    {"drb": 0, "ue": 2051, "qfiList": [0], "rlcType": "UM"}, \
    {"drb": 1, "ue": 2051, "qfiList": [6], "rlcType": "UM"}]

*.ue[*].cellularNic.sdap.drbConfig = [ \
    {"drb": 0, "qfiList": [0], "rlcType": "UM"}, \
    {"drb": 1, "qfiList": [6], "rlcType": "UM"}]
```

`ue` fields on the gNB side are NR MacNodeIds, which for UEs declared in
array order start at 2049 by default. Optional per-DRB scheduler QoS
parameters (used by the `QOS_PF` scheduling discipline) are configured
separately via `mac.drbQosConfig`.

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

## Build Instructions

### Prerequisites
- OMNeT++ 6.3 (6.1–6.4 also supported)
- INET 4.6.x, built
- Simu5G v1.5.0, built

No source modifications to Simu5G are required — SDAP/DRB support is
native to Simu5G v1.5.0.

### Project setup

nascTime is a standalone OMNeT++ project. Place it alongside your `inet`
and `simu5g` checkouts and add both as **project references**:

1. In the OMNeT++ IDE: right-click the nascTime project → *Properties* →
   *Project References* → tick your `inet` and `simu5g` projects.
2. Also under *Properties* → *OMNeT++* → *Makemake*, select the `src`
   folder and confirm both sibling projects' `src` directories are listed
   as include paths (not just library paths) on the Compile tab — this is
   required for headers to resolve, in addition to the Link tab's library
   references.
3. Regenerate Makefiles and build (*Project* → *Build Project*), or from
   the command line:
   ```bash
   cd nascTime/src
   make MODE=release all
   ```

### Running a scenario

```bash
cd nascTime/simulations/demos/multi_endpoint_test
opp_run -u Cmdenv -c MultiEndpointTest -f omnetpp.ini \
  -n ".:../../../src:<inet>/src:<simu5g>/src" \
  -l ../../../src/nascTime -l <simu5g>/src/simu5g -l <inet>/src/INET
```

Adjust the `<inet>`/`<simu5g>` paths to match your local checkout layout.

---

## Known Limitations

1. **TSN AF TAS gate control** parsed and logged but not programmatically
   applied to TSN Device A's `Ieee8021qTimeAwareShaper`.

2. **Static BMCA** validates topology but does not dynamically reconfigure
   gPTP port roles. INET's `Gptp` module does not support dynamic BMCA.

3. **DRB-enabled UE variant (`NRUeDsTtDrb.ned`)** is being finalized for
   Simu5G v1.5.0's SDAP/DRB module layout. Until that lands, use `NRUeDsTt`
   with `hasSdap=true` and a `drbConfig` list for multi-DRB QoS scenarios.

4. **FRER inter-PDU-session transport diversity (F3)** is implemented but
   has not yet completed full end-to-end integration testing across all
   scenario configurations.

5. **FRER NR dual-connectivity transport diversity (F4)** is under active
   development and not yet available for use.

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
