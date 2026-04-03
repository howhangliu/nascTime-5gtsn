//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// DsTt — Device-side TSN Translator compound module
//
// 3GPP TS 23.501 §5.28.4: the DS-TT is the egress bridge port of the
// 5G system when acting as a TSN bridge.
//
// Architecture: a simple two-port Ethernet bridge.
//   - tsnEthg: Ethernet port facing TSN Device B (or TSN switch)
//   - ueEthg: Ethernet port facing the UE's eth[0] interface
//   - DsTtTranslator: forwards frames between the two ports
//
// For G1, this is a transparent L2 forwarder. The translator simply
// passes frames from one port to the other, preserving MAC headers.
//
// Topology:
//   TsnDeviceB.ethg++ <--> Eth1G <--> dsTt.tsnEthg
//   dsTt.ueEthg <--> Eth1G <--> ue[0].ethg++
//

package simu5g.nodes.nascTime.DsTt;

import inet.linklayer.ethernet.basic.EthernetInterface;
import inet.networklayer.common.InterfaceTable;

module DsTt
{
    parameters:
        @display("i=abstract/switch;bgb=500,300");
        @networkNode();

        *.interfaceTableModule = default(absPath(".interfaceTable"));

    gates:
        // Facing TSN Device B
        inout tsnEthg @labels(EthernetSignal);
        // Facing UE's eth[0]
        inout ueEthg @labels(EthernetSignal);
        // gPTP sideband (connects from GptpSideband module)
        input gptpSidebandIn @loose;

    submodules:
        interfaceTable: InterfaceTable {
            @display("p=80,50;is=s");
        }

        // Ethernet interface facing TSN device
        tsnEth: EthernetInterface {
            parameters:
                @display("p=150,230");
        }

        // Ethernet interface facing UE
        ueEth: EthernetInterface {
            parameters:
                @display("p=350,230");
        }

        // The translator (L2 forwarder, with hooks for G2/G3/G4)
        translator: DsTtTranslator {
            parameters:
                @display("p=250,100");
        }

    connections:
        // External gates
        tsnEthg <--> tsnEth.phys;
        ueEthg <--> ueEth.phys;

        // TSN side ↔ translator
        tsnEth.upperLayerOut --> translator.tsnIn;
        tsnEth.upperLayerIn <-- translator.tsnOut;

        // UE side ↔ translator
        ueEth.upperLayerOut --> translator.ueIn;
        ueEth.upperLayerIn <-- translator.ueOut;


		gptpSidebandIn --> translator.gptpIn;
}
