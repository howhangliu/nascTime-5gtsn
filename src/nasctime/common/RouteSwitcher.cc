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

#include "nasctime/common/RouteSwitcher.h"

#include <inet/networklayer/common/L3AddressResolver.h>
#include <inet/networklayer/common/NetworkInterface.h>

Define_Module(RouteSwitcher);

void RouteSwitcher::handleMessage(cMessage *msg)
{
    throw cRuntimeError("RouteSwitcher receives no messages; it is driven by "
                        "ScenarioManager through processCommand()");
}

const char *RouteSwitcher::getRequiredAttribute(const cXMLElement& node, const char *attr)
{
    const char *value = node.getAttribute(attr);
    if (!value || !*value)
        throw cRuntimeError("Missing or empty '%s' attribute in <%s> at %s",
                attr, node.getTagName(), node.getSourceLocation());
    return value;
}

inet::Ipv4Address RouteSwitcher::resolveAddress(const cXMLElement& node, const char *attr)
{
    const char *spec = getRequiredAttribute(node, attr);

    if (inet::Ipv4Address::isWellFormed(spec))
        return inet::Ipv4Address(spec);

    // L3AddressResolver's own syntax, so "ue[1]%eth0" picks one interface of a
    // multi-homed node. Worth spelling out for anything with more than one
    // address: a bare module name yields whichever interface the resolver
    // happens to reach first, which on a UE is the cellular one, not the
    // Ethernet port a TSN-side gateway is supposed to be.
    inet::L3Address address;
    if (!inet::L3AddressResolver().tryResolve(spec, address, inet::L3AddressResolver::ADDR_IPv4))
        throw cRuntimeError("Cannot resolve '%s=\"%s\"' in <%s> at %s to an IPv4 address",
                attr, spec, node.getTagName(), node.getSourceLocation());
    if (address.getType() != inet::L3Address::IPv4 || address.toIpv4().isUnspecified())
        throw cRuntimeError("'%s=\"%s\"' in <%s> at %s has no IPv4 address",
                attr, spec, node.getTagName(), node.getSourceLocation());
    return address.toIpv4();
}

void RouteSwitcher::processCommand(const cXMLElement& node)
{
    if (strcmp(node.getTagName(), "set-route") != 0)
        throw cRuntimeError("Unknown command <%s> at %s; RouteSwitcher understands <set-route>",
                node.getTagName(), node.getSourceLocation());

    const char *hostSpec = getRequiredAttribute(node, "host");
    cModule *host = getSimulation()->getSystemModule()->getModuleByPath(hostSpec);
    if (!host)
        throw cRuntimeError("No such module '%s' (host attribute of <set-route> at %s)",
                hostSpec, node.getSourceLocation());

    inet::IIpv4RoutingTable *routingTable = inet::L3AddressResolver().findIpv4RoutingTableOf(host);
    if (!routingTable)
        throw cRuntimeError("Module '%s' has no IPv4 routing table", hostSpec);

    inet::Ipv4Address destination = resolveAddress(node, "destination");
    inet::Ipv4Address gateway = resolveAddress(node, "gateway");

    // Optional: move the route to a different outgoing interface as well. Not
    // needed when both next hops sit on the same link, which is the usual
    // active/standby case.
    const char *interfaceName = node.getAttribute("interface");
    inet::NetworkInterface *interface = nullptr;
    if (interfaceName && *interfaceName) {
        interface = inet::L3AddressResolver().findInterfaceTableOf(host)->findInterfaceByName(interfaceName);
        if (!interface)
            throw cRuntimeError("Module '%s' has no interface named '%s'", hostSpec, interfaceName);
    }

    // Retarget every route the destination currently falls into. Directly
    // connected routes are left alone: they describe a link rather than a next
    // hop, and giving one a gateway would be wrong rather than merely useless.
    int changed = 0;
    for (int i = 0; i < routingTable->getNumRoutes(); i++) {
        inet::Ipv4Route *route = routingTable->getRoute(i);
        if (route->getGateway().isUnspecified())
            continue;
        if (!inet::Ipv4Address::maskedAddrAreEqual(destination, route->getDestination(), route->getNetmask()))
            continue;

        EV_INFO << "RouteSwitcher: " << hostSpec << " route to " << route->getDestination()
                << "/" << route->getNetmask() << " now via " << gateway
                << " (was " << route->getGateway() << ")" << endl;

        // setGateway() notifies the routing table, which drops its lookup
        // cache, so the very next packet takes the new next hop.
        route->setGateway(gateway);
        if (interface)
            route->setInterface(interface);
        changed++;
    }

    if (changed == 0)
        throw cRuntimeError("No route on '%s' covers %s, so <set-route> at %s changed nothing; "
                            "a silent no-op here would look exactly like a working failover",
                hostSpec, destination.str().c_str(), node.getSourceLocation());

    bubble((std::string("route to ") + destination.str() + " via " + gateway.str()).c_str());
}
