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

package nasctime.common;

//
// Retargets IPv4 routes at runtime, driven by INET's ScenarioManager.
//
// ScenarioManager can set module and channel parameters but has no command for
// the routing table, so a scripted path change has nowhere to land. This module
// is the missing command: ScenarioManager hands any tag it does not recognize
// to the module named in the tag's `module` attribute, provided that module
// implements IScriptable.
//
// Syntax:
//
//   <set-route module="routeSwitcher" host="tsnDeviceB"
//              destination="tsnDeviceA" gateway="ue[1]%eth0"/>
//
//   module        this module
//   host          whose routing table to edit
//   destination   which routes to retarget: every route the destination falls
//                 into is moved, directly connected ones excepted
//   gateway       the new next hop
//   interface     optional, the new outgoing interface; only needed when the
//                 two next hops are not on the same link
//
// `destination` and `gateway` each take either a dotted-quad address or
// anything L3AddressResolver understands, which is the way the .ini files name
// nodes plus "%ifname" to pick one interface of a multi-homed node. Spell the
// interface out for anything with more than one address: a bare module name
// resolves to whichever interface comes first, and on a UE that is the
// cellular one rather than the Ethernet port facing the TSN island.
//
// The command fails loudly if it matches no route, because a scripted failover
// that quietly does nothing looks the same as one that works.
//
// The module is inert unless a script addresses it, so it costs nothing to
// leave in a network.
//
simple RouteSwitcher
{
    parameters:
        @display("i=block/cogwheel_s");
}
