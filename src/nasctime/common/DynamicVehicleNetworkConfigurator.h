#ifndef __NASCTIME_DYNAMICVEHICLENETWORKCONFIGURATOR_H
#define __NASCTIME_DYNAMICVEHICLENETWORKCONFIGURATOR_H

#include <omnetpp.h>

namespace nasctime {

// Recomputes INET addressing/routing after Veins adds a dynamic vehicle.
class DynamicVehicleNetworkConfigurator : public omnetpp::cSimpleModule, public omnetpp::cListener
{
  protected:
    omnetpp::simsignal_t moduleAddedSignal;
    omnetpp::simsignal_t moduleUpdatedSignal;
    omnetpp::cModule *manager = nullptr;

    void updateVehicleDisplay(omnetpp::cModule *vehicle);

    virtual void initialize() override;
    virtual void handleMessage(omnetpp::cMessage *message) override;
    virtual void receiveSignal(omnetpp::cComponent *source, omnetpp::simsignal_t signal,
            omnetpp::cObject *object, omnetpp::cObject *details) override;

  public:
    virtual ~DynamicVehicleNetworkConfigurator();
};

} // namespace nasctime

#endif
