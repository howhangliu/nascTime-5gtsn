//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// This file is part of a software released under the license included in file
// "LICENSE.txt". Please read LICENSE.txt and README files before using it.
// The above files and the present reference are part of the software itself,
// and cannot be removed from it.
//

package nasctime.nodes.frer;

simple FrerReplicator
{
    parameters:
        @display("i=block/fork");
        @class(::FrerReplicator);

        // Comma-separated DSCP values identifying FRER-eligible streams.
        // Packets with a matching IPv4 DSCP are replicated; all others
        // pass through unchanged.
        string frerStreams = default("7");

        // DSCP assigned to the replica by DrbTransportBinding.
        // Must correspond to a QFI→DRB mapping in the SDAP configuration.
        int replicaDscp = default(8);

        // Transport binding type: "drb", "pduSession", "dualConnectivity"
        string transportBinding = default("drb");

        // Path to InterfaceTable module().
        string interfaceTableModule = default("^.interfaceTable");

        // Name of the second ppp interface for replica routing.
        // Required when transportBinding = "pduSession" or "dualConnectivity".
        // Leave empty for "drb" binding.
        string replicaInterface = default("");

        // When true, packets arrive with Ethernet framing (DS-TT uplink).
        // When false, packets are bare IPv4 (NW-TT downlink — default).
        bool ethernetFramed = default(false);

        // Optional deterministic 2D availability regions for mobility
        // scenarios. Disabled by default, preserving existing FRER behavior.
        bool coverageFilteringEnabled = default(false);
        string mobilityModule = default("");
        double primaryCenterX @unit(m) = default(0m);
        double primaryCenterY @unit(m) = default(0m);
        double replicaCenterX @unit(m) = default(0m);
        double replicaCenterY @unit(m) = default(0m);
        double coverageRadius @unit(m) = default(0m);

        // --- Signals & statistics ---
        @signal[replicatedFrames](type=long);
        @signal[primarySent](type=long);
        @signal[replicaSent](type=long);
        @signal[passedThrough](type=long);
        @signal[primaryUnavailable](type=long);
        @signal[replicaUnavailable](type=long);
        @signal[primaryOnly](type=long);
        @signal[bothAvailable](type=long);
        @signal[replicaOnly](type=long);
        @signal[noMemberAvailable](type=long);

        @statistic[replicatedFrames](title="Frames replicated by FRER"; record=count,vector);
        @statistic[primarySent](title="Primary copies sent"; record=count);
        @statistic[replicaSent](title="Replica copies sent"; record=count);
        @statistic[passedThrough](title="Non-FRER frames passed through"; record=count);
        @statistic[primaryUnavailable](title="Primary copies suppressed outside coverage"; record=count);
        @statistic[replicaUnavailable](title="Replica copies suppressed outside coverage"; record=count);
        @statistic[primaryOnly](title="Reports generated in primary-only region"; record=count);
        @statistic[bothAvailable](title="Reports generated in overlap region"; record=count);
        @statistic[replicaOnly](title="Reports generated in replica-only region"; record=count);
        @statistic[noMemberAvailable](title="Reports generated outside both regions"; record=count);

    gates:
        input  in;
        output out;
}
