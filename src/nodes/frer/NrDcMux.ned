
//
//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
// DcMux — Simple bidirectional multiplexer for NR-DC.
//
// Merges downlink traffic from two NR stacks (primary + secondary)
// toward ip2nic, and routes uplink traffic from ip2nic to the
// primary stack only.
//
package nasctime.nodes.frer;

simple NrDcMux
{
    parameters:
        @display("i=block/dispatch");
    gates:
        inout upper;       // to ip2nic.stackNic
        inout primary;     // to sdap  (NR stack 1 / primary cell group)
        inout secondary;   // to sdap2 (NR stack 2 / secondary cell group)
}
