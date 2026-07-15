//
// nascGNodeB: extends Simu5G's gNodeB with a second PPP path to a second
// gateway (UPF), enabling FRER inter-session transport diversity.
//
// Mirrors the single-ppp/pppIf/gtpUser/trafficFlowFilter block in
// simu5g.nodes.eNodeB (confirmed against v1.5.0 source), duplicated for a
// second session. NOT a core patch — no Simu5G file is modified; this is a
// pure subclass living in nascTime's own tree.
//
package nasctime.nodes;

import simu5g.nodes.gNodeB;
import inet.linklayer.ppp.PppInterface;
import inet.common.MessageDispatcher;
import simu5g.corenetwork.gtp.GtpUser;
import simu5g.corenetwork.trafficFlowFilter.TrafficFlowFilter;

module NGNodeB extends gNodeB
{
    parameters:
        bool frerInterSession = default(false);

    gates:
        inout ppp2 @loose; // second N3 link for FRER inter-session / NR-DC

    submodules:
        pppIf2: PppInterface if frerInterSession {
            @display("p=824,600");
        }

    connections allowunconnected:
         pppIf2.phys <--> ppp2 if frerInterSession;
         pppIf2.upperLayerOut --> nl.in++ if frerInterSession;
         pppIf2.upperLayerIn <-- nl.out++ if frerInterSession;
}
