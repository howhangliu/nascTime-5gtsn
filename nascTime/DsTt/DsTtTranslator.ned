//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// DsTtTranslator — Device-side TSN Translator
//
// 3GPP TS 23.501 §5.28.4: the DS-TT is the egress bridge port of the
// 5G system when acting as a TSN bridge. It sits at the UE side.
//
// For G1: simple L2 frame forwarder between two Ethernet ports.
// Future extensions:
//   G2: gPTP sync message handling (ethertype 0x88F7 interception)
//   G3: Residence time egress stamping + correctionField update
//   G4: QFI → PCP mapping on egress frames
//


package simu5g.nodes.nascTime.DsTt;

simple DsTtTranslator
{
    parameters:
        @display("i=block/routing");
        @class(::DsTtTranslator);
		int gptpEncapUdpPort = default(30001);  // must match NW-TT's port
		
        // --- Signals & statistics ---
        @signal[tsnToUeForwarded](type=long);
        @signal[ueToTsnForwarded](type=long);
        @signal[packetDropped](type=long);

        @statistic[tsnToUeForwarded](title="Frames forwarded TSN→UE"; record=count);
        @statistic[ueToTsnForwarded](title="Frames forwarded UE→TSN"; record=count);
        @statistic[packetDropped](title="Packets dropped"; record=count);

        @signal[residenceTime](type=simtime_t);
        @statistic[residenceTime](title="5GS bridge residence time"; record=vector,histogram; unit=s);

    gates:
        // Facing TSN Device B
        input tsnIn;
        output tsnOut;

        // Facing UE's eth[0]
        input ueIn;
        output ueOut;

        // gPTP sideband input (from GptpSideband module)
        input gptpIn;
}
