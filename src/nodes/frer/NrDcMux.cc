//
// DcMux — bidirectional multiplexer for NR-DC UE NIC.
//
// Downlink: packets from either NR stack (primary or secondary)
//           are forwarded to ip2nic (upper).
// Uplink:   packets from ip2nic are forwarded to the primary
//           NR stack only (secondary is receive-only for FRER).
//
#include "NrDcMux.h"

namespace simu5g {

Define_Module(NrDcMux);

void NrDcMux::initialize()
{
    upperInId     = gate("upper$i")->getId();
    upperOutId    = gate("upper$o")->getId();
    primaryInId   = gate("primary$i")->getId();
    primaryOutId  = gate("primary$o")->getId();
    secondaryInId = gate("secondary$i")->getId();
    secondaryOutId= gate("secondary$o")->getId();
}

void NrDcMux::handleMessage(cMessage *msg)
{
    int gateId = msg->getArrivalGateId();

    if (gateId == primaryInId || gateId == secondaryInId) {
        // Downlink: forward from either NR stack to ip2nic
        send(msg, upperOutId);
    }
    else if (gateId == upperInId) {
        // Uplink: route to primary NR stack
        send(msg, primaryOutId);
    }
    else {
        EV_WARN << "DcMux: unexpected gate, dropping" << endl;
        delete msg;
    }
}
}// namespace
