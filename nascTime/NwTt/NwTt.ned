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
import inet.linklayer.ethernet.modular.LayeredEthernetInterface;
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

        string ueAddress;
        string localAddress;

    gates:
        inout tsnEthg @labels(EthernetSignal);
        inout filterGate @loose @labels(PppFrame-conn);
        output gptpSidebandOut @loose;

    submodules:
        ethIf: LayeredEthernetInterface {
            parameters:
                bitrate = default(1Gbps);
                phyLayer.typename = "EthernetStreamingPhyLayer";
                processingDelayLayer.typename = "OmittedProcessingDelayLayer";
                trafficConditionerLayer.typename = "OmittedTrafficConditionerLayer";
                measurementLayer.typename = "OmittedMeasurementLayer";
                @display("p=500,1000");
        }

        pppIf: PppInterface {
            parameters:
                @display("p=1150,1000");
        }

        udp: Udp {
            parameters:
                @display("p=375,200");
        }

        // H3/H5: EthernetEncapsulation for egress path (5GS → TSN)
        // registerProtocol=true so it registers ethernetmac service on nl → ipv4.lp
        // Connected to nl (upper) and ethLi (lower)
        encap: EthernetEncapsulation {
            parameters:
                @display("p=350,800");
                registerProtocol = false;
        }

        translator: NwTtTranslator {
            parameters:
                @display("p=675,80");
                ueAddress = parent.ueAddress;
                localAddress = parent.localAddress;
        }

        // H5: Dispatcher between LayeredEthernetInterface and translator/encap
        ethLi: MessageDispatcher {
            parameters:
                @display("p=500,900;b=500,5,,,,1");
                // Route ethernetmac SERVICE requests to ethIf (gate out[0])
                serviceMapping = {"ethernetmac": "ethIf"};
        }

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

        // H5: ethIf ↔ ethLi (must be first connection so ethIf = gate[0])
        ethIf.upperLayerOut --> ethLi.in++;
        ethIf.upperLayerIn <-- ethLi.out++;

        // INGRESS: ethLi → translator (gate[1])
        ethLi.out++ --> translator.ethIn;
        ethLi.in++ <-- translator.ethOut;

        // EGRESS lower: encap ↔ ethLi (gate[2])
        encap.lowerLayerOut --> ethLi.in++;
        encap.lowerLayerIn <-- ethLi.out++;

        // EGRESS upper: encap ↔ nl (for IPv4 routing + service registration)
        encap.upperLayerOut --> nl.in++;
        encap.upperLayerIn <-- nl.out++;

        // === UPF PPP port ===
        filterGate <--> pppIf.phys;
        pppIf.upperLayerOut --> nl.in++;
        pppIf.upperLayerIn <-- nl.out++;

        // === Translator ↔ at dispatcher ===
        translator.socketOut --> at.in++;
        translator.socketIn <-- at.out++;

        // Direct path for forwarding raw IP datagrams
        translator.ipForwardOut --> nl.in++;
        translator.ipForwardIn <-- nl.out++;

        // === at ↔ UDP ===
        at.out++ --> udp.appIn;
        at.in++ <-- udp.appOut;

        // === at ↔ tn ===
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

        // gPTP sideband
        translator.gptpOut --> gptpSidebandOut;
}