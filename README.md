# nascTime (5G-TSN Bridge)

## Overview

This package implements the 3GPP Release 16 5G-TSN integration bridge model
(TS 23.501 §5.28) for the OMNeT++ / INET / Simu5G simulation stack. The 5G
system acts as a transparent IEEE 802.1AS-compliant bridge between two TSN
network segments.

**Stack:** OMNeT++ 6.3 · INET 4.6.x · Simu5G v1.4.3

**End-to-end path:**
```
TSN Device A → TsnSwitch → NW-TT → UPF → gNB ~~NR~~ UE → DS-TT → TSN Device B
```

**Validated results (10s simulation, 1ms CBR traffic):**
- Data delivery: 9990/9992 packets (99.98%)
- gPTP frames transported: 158 (via L2-in-GTP-U through actual 5GS)
- 5GS residence time: ~2.5ms (measured, reported in gPTP correctionField)

---

## Completed Gaps

| Gap | Description | Status |
|-----|-------------|--------|
| G1  | NW-TT and DS-TT bridge port modules | ✅ Complete |
| G2  | gPTP tunnel transport (sideband + L2-in-GTP-U) | ✅ Complete |
| G3  | Residence time correction (transparent clock) | ✅ Complete |
| G4  | QoS mapping (PCP ↔ 5QI) | Pending |
| G5  | TSN AF / CNC configuration stub | Pending |
| G7  | Digital twin export hooks | Pending |

---

## File Inventory

### Source modules (`src/nodes/`)

```
src/nodes/NwTt/                          NW-TT (Network-side TSN Translator)
├── NwTt.ned                             Compound module (extends NetworkLayerNodeBase)
├── NwTtTranslator.ned                   Simple module (L2↔IP translation)
├── NwTtTranslator.h                     C++ header
├── NwTtTranslator.cc                    C++ implementation
├── GptpSideband.ned                     gPTP sideband delay module (fallback)
├── GptpSideband.h                       C++ header
├── GptpSideband.cc                      C++ implementation
└── GptpResidenceHeader.msg              Residence time header (auto-compiled)

src/nodes/DsTt/                          DS-TT (Device-side TSN Translator)
├── DsTt.ned                             Compound module (two-port L2 bridge)
├── DsTtTranslator.ned                   Simple module (L2 forwarder + gPTP handler)
├── DsTtTranslator.h                     C++ header
└── DsTtTranslator.cc                    C++ implementation

src/nodes/NR/
└── NRUeDsTt.ned                         NR UE with Ethernet port for DS-TT (NED only)
```

### Simulations (`simulations/NR/`)

```
simulations/NR/nwtt_test/                NW-TT only baseline
├── NwTtTestNetwork.ned                  Topology: TsnDevice → NwTt → UPF → gNB → UE
├── omnetpp.ini                          Configuration
└── nwtt_ip_config.xml                   IP addressing

simulations/NR/bridge_test/              Full bridge without gPTP
├── BridgeTestNetwork.ned                Topology: adds DS-TT + TsnDeviceB
├── omnetpp.ini                          Configuration
└── bridge_ip_config.xml                 IP addressing

simulations/NR/gptp_bridge_test/         Full bridge with gPTP (L2-in-GTP-U + G3)
├── GptpBridgeTestNetwork.ned            Topology: adds GptpSideband + gPTP config
├── omnetpp.ini                          Configuration (gPTP + residence time)
└── gptp_bridge_ip_config.xml            IP addressing
```

---

## Architecture

### NW-TT (Network-side TSN Translator)

**Module:** `NwTt extends NetworkLayerNodeBase`

The NW-TT is the ingress bridge port (TS 23.501 §5.28.3). It connects the
external TSN network to the UPF.

```
                    NwTt compound module
            ┌──────────────────────────────────┐
            │                                  │
TSN Switch ◄──► EthernetInterface (ethIf)      │
            │        │                         │
            │        ▼                         │
            │  NwTtTranslator                  │
            │   ├─ Data: strip Eth, forward    │
            │   │  IPv4 directly to pppIf      │
            │   │  via nl dispatcher           │
            │   └─ gPTP: detect 0x88F7,        │
            │      wrap in UDP:30001,           │
            │      prepend GptpResidenceHeader, │
            │      send through pppIf           │
            │        │                         │
            │        ▼                         │
            │  PppInterface (pppIf) ──────────►│◄──► UPF.filterGate
            │                                  │
            │  (also: UDP, IPv4, MessageDispatchers │
            │   from NetworkLayerNodeBase)      │
            └──────────────────────────────────┘
```

**Key design decisions:**
- Extends `NetworkLayerNodeBase` (same pattern as `Upf.ned`)
- Dedicated `ethIf` (EthernetInterface, non-layered) for TSN port
- Dedicated `pppIf` for UPF connection
- Data path bypasses NW-TT's own IPv4 stack (avoids double encapsulation)
  using `InterfaceReq` tag to route directly to `pppIf`
- gPTP frames detected by ethertype check before MAC header stripping
- Registers downstream TSN device IPs with Simu5G binder for GTP routing

### DS-TT (Device-side TSN Translator)

**Module:** `DsTt` (standalone two-port L2 bridge)

The DS-TT is the egress bridge port (TS 23.501 §5.28.4). It connects
the UE's Ethernet interface to the downstream TSN device.

```
            DsTt compound module
    ┌────────────────────────────────┐
    │                                │
UE ◄──► EthernetInterface (ueEth)   │   (promiscuous mode)
    │        │                       │
    │        ▼                       │
    │  DsTtTranslator                │
    │   ├─ Data: strip Eth from UE,  │
    │   │  rebuild Eth frame,        │
    │   │  send to tsnEth            │
    │   └─ gPTP: detect UDP:30001,   │
    │      strip IP+UDP,             │
    │      read GptpResidenceHeader, │
    │      compute residence time,   │
    │      update correctionField,   │
    │      emit original gPTP frame  │
    │        │                       │
    │        ▼                       │
    │  EthernetInterface (tsnEth) ──►│◄──► TSN Device B
    └────────────────────────────────┘
```

**Key design decisions:**
- Standalone node (not inside the UE) for modularity
- `ueEth` in promiscuous mode (accepts frames not addressed to it)
- `tsnEth` is plain `EthernetInterface` (matches non-streaming receivers)
- Builds complete Ethernet frames (MAC header + FCS) for `tsnEth` output
- Reads `GptpResidenceHeader` from L2-in-GTP-U payload for residence time

### NRUeDsTt (UE with Ethernet port)

**Module:** `NRUeDsTt extends NRUe` (NED only, no C++)

Adds an Ethernet interface to the standard NR UE for connecting to the DS-TT:
- Sets `numEthInterfaces = 1`
- Overrides interface type from `ExtLowerEthernetInterface` to `EthernetInterface`
- Activates `EthernetEncapsulation` for protocol handling
- Exposes `ethg` gate for external connection
- Requires `*.ue[0].ipv4.forwarding = true` in .ini

### gPTP Transport Modes

Two modes selectable via `*.nwTt.translator.gptpTransportMode`:

**`"gtpu"` (primary, recommended):**
- gPTP frames wrapped in UDP:30001 and sent through the actual 5GS data plane
- Experiences real NR scheduling delay, HARQ, GTP-U processing
- Carries `GptpResidenceHeader` with ingress timestamp inside the payload
- DS-TT computes actual 5GS residence time (~2.5ms measured)
- CorrectionField updated with measured residence time

**`"sideband"` (fallback):**
- gPTP frames sent via direct OMNeT++ connection (GptpSideband module)
- Configurable fixed delay (default 2ms)
- Does not model actual 5GS latency
- Useful for debugging or when 5GS path issues arise

### GptpResidenceHeader

**File:** `GptpResidenceHeader.msg` (auto-compiled)

Custom 8-byte header modelling the GTP-U PDU Session Container extension header
(TS 29.281 §5.2.1). Carries the NW-TT ingress timestamp through the 5GS alongside
the gPTP frame payload:

```
[IPv4 | UDP:30001 | GptpResidenceHeader(8B) | original gPTP Ethernet frame]
```

---

## Configuration Reference

### Essential .ini parameters

```ini
# Time resolution (required by gPTP)
simtime-resolution = fs

# IP / ARP
**.arp.typename = "GlobalArp"
*.configurator.addStaticRoutes = true

# Suppress statistics errors
**.vector-recording = false
**.scalar-recording = true
**.receivedPacketFromLowerLayer.result-recording-modes = -
**.packetReceived.result-recording-modes = -

# NW-TT
*.nwTt.ueAddress = "ue[0]"
*.nwTt.localAddress = "nwTt"
*.nwTt.translator.tsnDeviceBAddress = "tsnDeviceB"
*.nwTt.translator.gptpTransportMode = "gtpu"
*.nwTt.translator.gptpEncapUdpPort = 30001
*.nwTt.ethIf.bitrate = 1Gbps

# DS-TT
*.dsTt.ueEth.mac.promiscuous = true
*.dsTt.tsnEth.mac.promiscuous = true
*.dsTt.translator.gptpEncapUdpPort = 30001

# UE (NRUeDsTt)
*.ue[0].nrServingNodeId = 1
*.ue[0].ipv4.forwarding = true

# Ethernet bitrates
*.tsnDeviceA.eth[*].bitrate = 1Gbps
*.tsnSwitch.eth[*].bitrate = 1Gbps
*.tsnDeviceB.eth[*].typename = "EthernetInterface"

# gPTP
*.tsnDeviceA.hasTimeSynchronization = true
*.tsnDeviceA.gptp.gptpNodeType = "MASTER_NODE"
*.tsnDeviceA.gptp.masterPorts = ["eth0"]
*.tsnDeviceA.gptp.slavePort = ""

*.tsnSwitch.hasTimeSynchronization = true
*.tsnSwitch.gptp.gptpNodeType = "BRIDGE_NODE"
*.tsnSwitch.gptp.masterPorts = ["eth1"]
*.tsnSwitch.gptp.slavePort = "eth0"

*.tsnDeviceB.hasTimeSynchronization = true
*.tsnDeviceB.gptp.gptpNodeType = "SLAVE_NODE"
*.tsnDeviceB.gptp.slavePort = "eth0"
*.tsnDeviceB.gptp.masterPorts = []
*.tsnDeviceB.gptp.pdelayInterval = 1000s
*.tsnDeviceB.gptp.pdelayInitialOffset = 1000s

# Clock configuration
*.tsnDeviceA.clock.typename = "OscillatorBasedClock"
*.tsnDeviceA.clock.oscillator.nominalTickLength = 10ns
*.tsnDeviceB.clock.typename = "SettableClock"
*.tsnDeviceB.clock.oscillator.nominalTickLength = 10ns
*.tsnSwitch.clock.oscillator.nominalTickLength = 10ns
```

### IP addressing scheme

```
10.0.0.0/24     TSN domain A (tsnDeviceA, tsnSwitch, nwTt.ethIf)
10.0.1.0/24     NW-TT ↔ UPF link
10.0.2.0/24     UPF ↔ gNB link
10.0.3.0/24     Cellular (gNB ↔ UE)
192.168.1.0/24  UE ↔ DS-TT ↔ TSN Device B (separate from 10.0.x.x)
```

DS-TT interfaces get `0.0.0.0` (L2 bridge, no IP needed).

---

## Build Instructions

### Prerequisites
- OMNeT++ 6.3 installed and in PATH
- INET 4.6.x built
- Simu5G v1.4.3 built

### Integration

1. Copy all files from `src/nodes/NwTt/`, `src/nodes/DsTt/`, and
   `src/nodes/NR/NRUeDsTt.ned` into your Simu5G source tree.

2. Copy simulation directories from `simulations/NR/` into your
   Simu5G simulations tree.

3. Rebuild Simu5G:
   ```bash
   cd <simu5g>/src
   make -j$(nproc)
   ```

4. Run:
   ```bash
   cd <simu5g>/simulations/NR/gptp_bridge_test
   opp_run -u Qtenv -c GptpBridgeTest -f omnetpp.ini \
     -n ".:../../src:<inet>/src" \
     -l ../../src/simu5g -l <inet>/src/INET
   ```

---

## Known Limitations

1. **NW-TT pppIf interface ID (102) is hardcoded** in `NwTtTranslator.cc`.
   Should be looked up dynamically via InterfaceTable at init.

2. **NW-TT egress path (5GS → TSN via NW-TT)** is wired but untested.
   The UdpSocket is bound but no return traffic has been validated.

3. **DS-TT uses broadcast MAC** for egress data frames.
   Should learn/resolve destination MAC for unicast delivery.

4. **EthernetInterface (non-layered)** used for NW-TT ethIf and DS-TT ports.
   LayeredEthernetInterface is needed for TSN features like TAS, frame
   preemption, and proper gPTP peer delay measurement.

5. **TSN Device B peer delay disabled** (`pdelayInterval = 1000s`).
   The DS-TT doesn't participate in gPTP peer delay measurement.
   Enabling it requires LayeredEthernetInterface with streaming PHY.

6. **gPTP correctionField update** uses `removeAtFront<GptpBase>()` which
   may fail for some gPTP message types if chunk casting doesn't work.
   Should handle GptpSync, GptpFollowUp, PdelayReq/Resp separately.

7. **No VLAN tag preservation** across the bridge. PCP values are lost
   at the NW-TT when Ethernet headers are stripped.

8. **Single UE/DS-TT topology only.** Multi-UE requires array parameters
   for binder registration and per-UE DS-TT instances.

---

## Remaining Work (G4, G5, G7)

### G4: QoS Mapping (PCP ↔ 5QI) — estimated 2 weeks
- Map TSN PCP to 5QI/QFI at NW-TT, reverse at DS-TT
- Integrate with SDAP branch QFI-aware scheduling
- Multi-DRB configuration for traffic class differentiation
- Requires VLAN tag preservation (currently stripped)

### G5: TSN AF Stub — estimated 1.5 weeks
- Static configuration module exposing bridge parameters
- Bridge delay, port speed, supported traffic classes
- CNC schedule file reader for TAS gate configuration

### G7: Digital Twin Export — estimated 3 weeks
- ZeroMQ PUB socket sidecar module
- InfluxDB line protocol message format
- Grafana dashboard with live TSN flow latency and gPTP accuracy
- Alert on threshold breach (e.g., E2E delay > 5ms)

---

## References

- 3GPP TS 23.501 §5.28 — 5G-TSN integration architecture
- 3GPP TS 23.501 §5.28.3 — NW-TT functionality
- 3GPP TS 23.501 §5.28.4 — DS-TT functionality
- 3GPP TS 29.281 §5.2.1 — GTP-U PDU Session Container
- IEEE 802.1AS-2020 — Timing and Synchronization for TSN
- IEEE 802.1AS-2020 §11.2.14.2.3 — Transparent clock correction
