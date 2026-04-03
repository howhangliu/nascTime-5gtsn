//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// NwTt — Network-side TSN Translator compound module
//
// 3GPP TS 23.501 §5.28.3: the NW-TT is the ingress bridge port of the
// 5G system when it acts as a logical IEEE 802.1AS-compliant TSN bridge.
// It connects the external TSN network (via Ethernet) to the UPF (via IP/PPP).
//
// Placement in topology:
//   TsnSwitch.ethg <--> Eth1G <--> nwTt.ethg
//   nwTt.filterGate <--> Eth10G <--> upf.filterGate
//
// Note: the gate facing the UPF is named "filterGate" (not "pppg") to match
// the Simu5G convention used by Upf.ned and PgwStandard.ned, making it a
// drop-in replacement for the external router in standard topologies.
//

package simu5g.nodes.nascTime.NwTt;

import inet.common.MessageDispatcher;
import inet.linklayer.ethernet.basic.EthernetInterface;
import inet.linklayer.ethernet.basic.EthernetEncapsulation;
import inet.linklayer.ppp.PppInterface;
import inet.node.base.NetworkLayerNodeBase;
import inet.transportlayer.udp.Udp;

module NwTt extends NetworkLayerNodeBase
{
    parameters:
        @display("bgb=1348,1103;i=abstract/switch");
        @figure[applicationLayer](type=rectangle; pos=250,6; size=1000,130; lineColor=#808080; cornerRadius=5; fillColor=#ffff00; fillOpacity=0.1);
        @figure[applicationLayer.title](type=text; pos=1245,11; anchor=ne; text="application layer");
        @figure[transportLayer](type=rectangle; pos=250,156; size=1000,130; fillColor=#ff0000; lineColor=#808080; cornerRadius=5; fillOpacity=0.1);
        @figure[transportLayer.title](type=text; pos=1245,161; anchor=ne; text="transport layer");
        @figure[submodules];

        string nodeType = default("NWTT");
        forwarding = default(true);
        multicastForwarding = default(false);

        // NwTtTranslator config
        string ueAddress;
        string localAddress;

    gates:
        // TSN-facing Ethernet port (dedicated, not the inherited ethg[])
        inout tsnEthg @labels(EthernetSignal);

        // UPF-facing PPP port (same pattern as Upf.ned's filterGate)
        inout filterGate @loose @labels(PppFrame-conn);

		// gPTP sideband (connects to GptpSideband module in the network)
        output gptpSidebandOut;
    submodules:
        // --- Dedicated Ethernet interface for TSN port ---
        ethIf: EthernetInterface {
            parameters:
                @display("p=500,1000");
        }

        // --- Dedicated PPP interface for UPF port ---
        pppIf: PppInterface {
            parameters:
                @display("p=1150,1000");
        }

        // --- UDP transport ---
        udp: Udp {
            parameters:
                @display("p=375,200");
        }

        // H3: EthernetEncapsulation for egress path (5GS → TSN)
        encap: EthernetEncapsulation {
            parameters:
                @display("p=350,800");
                registerProtocol = true;
        }

        // --- NW-TT Translator ---
        translator: NwTtTranslator {
            parameters:
                @display("p=675,80");
                ueAddress = parent.ueAddress;
                localAddress = parent.localAddress;
        }

        // --- MessageDispatchers ---
        tn: MessageDispatcher {
            parameters:
                @display("p=750,300;b=1000,5,,,,1");
        }
        at: MessageDispatcher {
            parameters:
                @display("p=750,146;b=1000,5,,,,1");
        }

    connections:
        // === TSN Ethernet port ===
        tsnEthg <--> ethIf.phys;

        // INGRESS (TSN → 5GS): ethIf → translator directly
        ethIf.upperLayerOut --> translator.ethIn;

        // EGRESS (5GS → TSN): encap → ethIf
        ethIf.upperLayerIn <-- encap.lowerLayerOut;

        // encap connects to nl for egress routing
        // When IPv4 routes a packet to ethIf, nl sends it to encap,
        // which adds the Ethernet header and sends to ethIf
        encap.upperLayerOut --> nl.in++;
        encap.upperLayerIn <-- nl.out++;

        // encap ingress (from ethIf) is unused — translator handles ingress
        // but we need to connect the gate to avoid errors
        encap.lowerLayerIn <-- translator.ethOut;

        // === UPF PPP port ===
        filterGate <--> pppIf.phys;

        // pppIf connects to network layer dispatcher (normal INET routing)
        pppIf.upperLayerOut --> nl.in++;
        pppIf.upperLayerIn <-- nl.out++;

        // === Translator ↔ at dispatcher (socket-based communication) ===
        translator.socketOut --> at.in++;
        translator.socketIn <-- at.out++;

        // Direct path for forwarding raw IP datagrams (bypass UDP)
        translator.ipForwardOut --> nl.in++;
        translator.ipForwardIn <-- nl.out++;

        // === at ↔ UDP ===
        at.out++ --> udp.appIn;
        at.in++ <-- udp.appOut;

        // === at ↔ tn (for direct protocol access) ===
        at.out++ --> tn.in++;
        at.in++ <-- tn.out++;

        // === UDP ↔ tn ===
        udp.ipOut --> tn.in++;
        udp.ipIn <-- tn.out++;

        // === tn ↔ network layer ===
        tn.out++ --> nl.in++;
        tn.in++ <-- nl.out++;

        // === tn ↔ IPv4 transport ===
        tn.out++ --> ipv4.transportIn;
        tn.in++ <-- ipv4.transportOut;

        // gPTP sideband from translator to external gate
        translator.gptpOut --> gptpSidebandOut;
}
