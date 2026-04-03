//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//

#include "GptpSideband.h"

Define_Module(GptpSideband);

void GptpSideband::initialize()
{
    sidebandDelay = par("sidebandDelay");
}

void GptpSideband::handleMessage(cMessage *msg)
{
    int gateId = msg->getArrivalGateId();

    if (gateId == gate("nwttIn")->getId()) {
        // NW-TT → DS-TT: add 5GS transit delay
        sendDelayed(msg, sidebandDelay, "dsttOut");
    }
    else if (gateId == gate("dsttIn")->getId()) {
        // DS-TT → NW-TT: add 5GS transit delay (reverse)
        sendDelayed(msg, sidebandDelay, "nwttOut");
    }
    else {
        delete msg;
    }
}
