#include "nasctime/common/MobilityCsvRecorder.h"

#include <iomanip>

#include "inet/mobility/contract/IMobility.h"

using namespace omnetpp;

namespace nasctime {

Define_Module(MobilityCsvRecorder);

MobilityCsvRecorder::~MobilityCsvRecorder()
{
    cancelAndDelete(sampleTimer);
}

void MobilityCsvRecorder::initialize()
{
    nodePath = par("nodePath").stdstringValue();
    sampleInterval = par("sampleInterval");
    if (sampleInterval <= SIMTIME_ZERO)
        throw cRuntimeError("sampleInterval must be positive");

    const char *outputFile = par("outputFile");
    output.open(outputFile, std::ios::out | std::ios::trunc);
    if (!output.is_open())
        throw cRuntimeError("Cannot open mobility trace '%s'", outputFile);

    output << "time,node_id,x,y,z,speed\n";
    output << std::setprecision(12);

    sampleTimer = new cMessage("sampleMobility");
    scheduleAt(par("startTime"), sampleTimer);
}

void MobilityCsvRecorder::handleMessage(cMessage *message)
{
    if (message != sampleTimer)
        throw cRuntimeError("Unexpected message '%s'", message->getName());

    cModule *node = getSimulation()->getSystemModule()->findModuleByPath(nodePath.c_str());
    if (node != nullptr) {
        cModule *mobilityModule = node->getSubmodule("mobility");
        auto *mobility = dynamic_cast<inet::IMobility *>(mobilityModule);
        if (mobility == nullptr)
            throw cRuntimeError("%s.mobility does not implement inet::IMobility", nodePath.c_str());

        const inet::Coord position = mobility->getCurrentPosition();
        const inet::Coord velocity = mobility->getCurrentVelocity();
        output << simTime() << ',' << nodePath << ','
               << position.x << ',' << position.y << ',' << position.z << ','
               << velocity.length() << '\n';
        observedNode = true;
    }

    scheduleAt(simTime() + sampleInterval, sampleTimer);
}

void MobilityCsvRecorder::finish()
{
    output.flush();
    if (!observedNode)
        EV_WARN << "No node named " << nodePath << " appeared; mobility CSV contains only its header\n";
}

} // namespace nasctime
