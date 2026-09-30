#ifndef __NASCTIME_MOBILITYCSVRECORDER_H
#define __NASCTIME_MOBILITYCSVRECORDER_H

#include <fstream>

#include <omnetpp.h>

namespace nasctime {

/**
 * Periodically samples an INET mobility module and writes a stable CSV trace.
 *
 * The target may be created dynamically (as Veins vehicles are), so a missing
 * node is skipped until it appears instead of being treated as an error.
 */
class MobilityCsvRecorder : public omnetpp::cSimpleModule
{
  protected:
    omnetpp::cMessage *sampleTimer = nullptr;
    std::ofstream output;
    std::string nodePath;
    omnetpp::simtime_t sampleInterval;
    bool observedNode = false;

    virtual void initialize() override;
    virtual void handleMessage(omnetpp::cMessage *message) override;
    virtual void finish() override;

  public:
    virtual ~MobilityCsvRecorder();
};

} // namespace nasctime

#endif
