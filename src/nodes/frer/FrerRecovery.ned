//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// FrerRecovery — IEEE 802.1CB sequence recovery + individual recovery
//
// Standalone simple module implementing the Vector Recovery Algorithm
// (802.1CB §7.5, Annex C) and individual recovery / duplicate
// elimination (802.1CB §10.4).
//
// Placed between the ueLi MessageDispatcher and DsTtTranslator.ueIn
// in the DsTt compound module.  When frerEnabled=false in the compound
// module, this submodule is not instantiated and the original wiring
// is preserved.
//

package nasctime.nodes.frer;

simple FrerRecovery
{
    parameters:
        @display("i=block/join");
        @class(::FrerRecovery);

        // Comma-separated DSCP values identifying primary FRER streams.
        // Must match the frerStreams parameter of FrerReplicator.
        string frerStreams = default("7");

        // DSCP used for replica packets (must match FrerReplicator).
        int replicaDscp = default(8);

        // Recovery window size (number of sequence numbers tracked).
        // IEEE 802.1CB Annex C recommends 64.
        int windowSize = default(64);

        // Timeout (seconds) after which a stream's recovery state is
        // reset if no packet arrives.  Prevents stale bitmaps from
        // blocking sequence-number reuse after idle periods.
        double windowTimeout @unit(s) = default(0.1s);

        // When true, packets arrive with Ethernet framing (DS-TT downlink — default).
        // When false, packets are bare IPv4 (NW-TT uplink recovery).
        bool ethernetFramed = default(true);
        bool registerEthernetProtocol = default(true);

        // --- Signals & statistics ---
        @signal[recoveredFromPrimary](type=long);
        @signal[recoveredFromReplica](type=long);
        @signal[duplicatesDropped](type=long);
        @signal[windowOverruns](type=long);
        @signal[passedThrough](type=long);

        @statistic[recoveredFromPrimary](title="Frames recovered from primary"; record=count,vector);
        @statistic[recoveredFromReplica](title="Frames recovered from replica"; record=count,vector);
        @statistic[duplicatesDropped](title="Duplicate frames dropped"; record=count,vector);
        @statistic[windowOverruns](title="Frames dropped (outside window)"; record=count);
        @statistic[passedThrough](title="Non-FRER frames passed through"; record=count);

    gates:
        input  in;
        output out;
}
