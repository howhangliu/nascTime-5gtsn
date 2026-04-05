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

import inet.common.MessageDispatcher;
import inet.linklayer.ethernet.modular.LayeredEthernetInterface;
import inet.networklayer.common.InterfaceTable;

module DsTt
{
    parameters:
        @display("i=abstract/switch;bgb=500,400");
        @networkNode();
        *.interfaceTableModule = default(absPath(".interfaceTable"));

    gates:
        inout tsnEthg @labels(EthernetSignal);
        inout ueEthg @labels(EthernetSignal);
        input gptpSidebandIn @loose;

    submodules:
        interfaceTable: InterfaceTable {
            @display("p=80,50;is=s");
        }

        tsnEth: LayeredEthernetInterface {
            parameters:
                bitrate = default(1Gbps);
                phyLayer.typename = "EthernetStreamingPhyLayer";
                processingDelayLayer.typename = "OmittedProcessingDelayLayer";
                trafficConditionerLayer.typename = "OmittedTrafficConditionerLayer";
                measurementLayer.typename = "OmittedMeasurementLayer";
                @display("p=350,300");
        }

        ueEth: LayeredEthernetInterface {
            parameters:
                bitrate = default(1Gbps);
                phyLayer.typename = "EthernetPhyLayer";
                processingDelayLayer.typename = "OmittedProcessingDelayLayer";
                trafficConditionerLayer.typename = "OmittedTrafficConditionerLayer";
                measurementLayer.typename = "OmittedMeasurementLayer";
                @display("p=150,300");
        }

        translator: DsTtTranslator {
            parameters:
                @display("p=250,100");
        }

        // H5: Dispatchers between LayeredEthernetInterface and translator
        tsnLi: MessageDispatcher {
            parameters:
                @display("p=350,200;b=200,5,,,,1");
                serviceMapping = {"ethernetmac": "tsnEth"};
        }

        ueLi: MessageDispatcher {
            parameters:
                @display("p=150,200;b=200,5,,,,1");
                serviceMapping = {"ethernetmac": "ueEth"};
        }

    connections:
        // External gates
        tsnEthg <--> tsnEth.phys;
        ueEthg <--> ueEth.phys;

        // TSN side: tsnEth ↔ tsnLi ↔ translator (ethIf = gate[0], translator = gate[1])
        tsnEth.upperLayerOut --> tsnLi.in++;
        tsnEth.upperLayerIn <-- tsnLi.out++;
        tsnLi.out++ --> translator.tsnIn;
        tsnLi.in++ <-- translator.tsnOut;

        // UE side: ueEth ↔ ueLi ↔ translator (ethIf = gate[0], translator = gate[1])
        ueEth.upperLayerOut --> ueLi.in++;
        ueEth.upperLayerIn <-- ueLi.out++;
        ueLi.out++ --> translator.ueIn;
        ueLi.in++ <-- translator.ueOut;

        // gPTP sideband
        gptpSidebandIn --> translator.gptpIn;
}
