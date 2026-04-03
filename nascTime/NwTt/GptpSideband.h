//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//

#ifndef __SIMU5G_1_4_3_GPTPSIDEBAND_H_
#define __SIMU5G_1_4_3_GPTPSIDEBAND_H_

#include <omnetpp.h>
using namespace omnetpp;

class GptpSideband : public cSimpleModule
{
  protected:
    simtime_t sidebandDelay;
    virtual void initialize() override;
    virtual void handleMessage(cMessage *msg) override;
};

#endif
