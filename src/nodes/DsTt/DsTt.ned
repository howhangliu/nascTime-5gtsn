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
// FRER extension (IEEE 802.1CB):
//   When frerEnabled=true, a FrerRecovery submodule is conditionally
//   instantiated between the ueLi dispatcher and DsTtTranslator.ueIn.
//   It intercepts packets arriving from the UE, applies the Vector
//   Recovery Algorithm, and drops duplicates before they reach the
//   translator.  When frerEnabled=false (default), the original
//   direct wiring is preserved — zero overhead.
//

package nasctime.nodes.DsTt;

import inet.common.MessageDispatcher;
import inet.linklayer.ethernet.modular.LayeredEthernetInterface;
import inet.networklayer.common.InterfaceTable;
import nasctime.nodes.frer.FrerRecovery;
import nasctime.nodes.frer.FrerReplicator;

module DsTt
{
    parameters:
        @display("i=abstract/switch;bgb=500,400");
        @networkNode();
        *.interfaceTableModule = default(absPath(".interfaceTable"));

        // --- FRER (IEEE 802.1CB) ---
        // DL FRER: recovery between ueLi and translator.ueIn
        bool frerEnabled = default(false);
        // UL FRER: replication between translator.ueOut and ueLi
        bool frerUplinkEnabled = default(false);

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

        // FRER: conditional recovery module (only when frerEnabled=true)
        // DL FRER: recovery (UE → translator path)
        frerRecovery: FrerRecovery if frerEnabled {
            parameters:
                ethernetFramed = true;
                @display("p=150,100");
        }

        // UL FRER: replicator (translator → UE path)
        frerReplicatorUl: FrerReplicator if frerUplinkEnabled {
            parameters:
                ethernetFramed = true;
                @display("p=350,100");
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

        // TSN side: tsnEth ↔ tsnLi ↔ translator (unchanged)
        tsnEth.upperLayerOut --> tsnLi.in++;
        tsnEth.upperLayerIn <-- tsnLi.out++;
        tsnLi.out++ --> translator.tsnIn;
        tsnLi.in++ <-- translator.tsnOut;

        // UE side: ueEth ↔ ueLi ↔ [frerRecovery] ↔ translator
        ueEth.upperLayerOut --> ueLi.in++;
        ueEth.upperLayerIn <-- ueLi.out++;

        // === UE → translator path (with optional FRER recovery) ===
        //
        // When frerEnabled=true:
        //   ueLi → frerRecovery.in → frerRecovery.out → translator.ueIn
        //   (FrerRecovery drops duplicates, forwards first copy)
        //
        // When frerEnabled=false (DEFAULT):
        //   ueLi → translator.ueIn  (original wiring, unchanged)
        //
        // === DL path: UE → [FrerRecovery] → translator ===
        ueLi.out++ --> frerRecovery.in if frerEnabled;
        frerRecovery.out --> translator.ueIn if frerEnabled;
        ueLi.out++ --> translator.ueIn if !frerEnabled;

        // === UL path: translator → [FrerReplicatorUl] → ueLi ===
        translator.ueOut --> frerReplicatorUl.in if frerUplinkEnabled;
        frerReplicatorUl.out --> ueLi.in++ if frerUplinkEnabled;
        ueLi.in++ <-- translator.ueOut if !frerUplinkEnabled;

        // gPTP sideband
        gptpSidebandIn --> translator.gptpIn;
}
