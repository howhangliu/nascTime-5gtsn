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

#ifndef __NASCTIME_COMMON_ROUTESWITCHER_H_
#define __NASCTIME_COMMON_ROUTESWITCHER_H_

#include <omnetpp.h>
#include <inet/common/scenario/IScriptable.h>
#include <inet/networklayer/ipv4/Ipv4Route.h>
#include <inet/networklayer/ipv4/IIpv4RoutingTable.h>

using namespace omnetpp;

//
// Retargets IPv4 routes at runtime on behalf of INET's ScenarioManager.
//
// ScenarioManager can set module and channel parameters but has no command
// for the routing table (ScenarioManager.cc:99-114 is the whole list), so a
// scripted path change had nowhere to land. This module fills that gap: it
// implements IScriptable, which is the extension point ScenarioManager
// dispatches unrecognized tags to, and edits routes through the same
// IIpv4RoutingTable API a routing protocol would use.
//
class RouteSwitcher : public cSimpleModule, public inet::IScriptable
{
  protected:
    void handleMessage(cMessage *msg) override;

    // ScenarioManager entry point. See the .ned file for the command syntax.
    void processCommand(const cXMLElement& node) override;

    // Accepts either a dotted-quad literal or the name of a module, which is
    // resolved the way the .ini files name nodes ("tsnDeviceA", "ue[1]").
    inet::Ipv4Address resolveAddress(const cXMLElement& node, const char *attr);

    // Reads a required attribute, failing with the command's source location
    // rather than a bare null dereference.
    const char *getRequiredAttribute(const cXMLElement& node, const char *attr);
};

#endif
