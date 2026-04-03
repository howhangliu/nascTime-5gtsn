//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// Extends NRUe to add an Ethernet interface for connecting to a DS-TT module
// (or directly to a TSN device). This enables the UE to act as a radio
// adapter for TSN devices per 3GPP TS 23.501 §5.28.4.
//
// The Ethernet interface connects to the existing nl (network layer)
// MessageDispatcher, so IP traffic is routed between the cellular NIC
// and the Ethernet interface by the UE's standard IPv4 routing.
//
// Usage:
//   ue[1]: NRUeDsTt { @display("p=960,350"); }
//   ue[0].ethg <--> Eth1G <--> dsTt.ueEthg;
//
// Requires *.ue[0].forwarding = true in .ini so the UE routes between
// cellular and Ethernet interfaces.
//

package simu5g.nodes.nascTime.DsTt;

import inet.linklayer.ethernet.basic.EthernetInterface;
import simu5g.nodes.NrUe;

module NRUeDsTt extends NrUe
{
    parameters:
        @display("i=device/pocketpc;bgb=858,750");
        numEthInterfaces = default(1);
        eth[*].typename = default("EthernetInterface");
        encap.typename = default("EthernetEncapsulation");

    gates:
        inout ethg @labels(EthernetSignal);

    connections:
        ethg <--> eth[0].phys;
}
