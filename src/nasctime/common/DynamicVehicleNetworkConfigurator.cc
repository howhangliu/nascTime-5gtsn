#include "nasctime/common/DynamicVehicleNetworkConfigurator.h"

#include "inet/networklayer/common/L3AddressResolver.h"
#include "inet/networklayer/configurator/ipv4/Ipv4NetworkConfigurator.h"
#include "inet/mobility/contract/IMobility.h"
#include "simu5g/common/binder/Binder.h"
#include "simu5g/common/LteCommon.h"

using namespace inet;
using namespace omnetpp;

namespace nasctime {

Define_Module(DynamicVehicleNetworkConfigurator);

DynamicVehicleNetworkConfigurator::~DynamicVehicleNetworkConfigurator()
{
    if (manager != nullptr)
        manager->unsubscribe(moduleAddedSignal, this);
    if (manager != nullptr)
        manager->unsubscribe(moduleUpdatedSignal, this);
}

void DynamicVehicleNetworkConfigurator::initialize()
{
    manager = getSystemModule()->getSubmodule("veinsManager");
    if (manager == nullptr)
        throw cRuntimeError("veinsManager not found");

    moduleAddedSignal = cComponent::registerSignal("org_car2x_veins_modules_mobility_traciModuleAdded");
    moduleUpdatedSignal = cComponent::registerSignal("org_car2x_veins_modules_mobility_traciModuleUpdated");
    manager->subscribe(moduleAddedSignal, this);
    manager->subscribe(moduleUpdatedSignal, this);
}

void DynamicVehicleNetworkConfigurator::handleMessage(cMessage *message)
{
    throw cRuntimeError("Unexpected message '%s'", message->getName());
}

void DynamicVehicleNetworkConfigurator::receiveSignal(cComponent *, simsignal_t signal,
        cObject *object, cObject *)
{
    if (signal != moduleAddedSignal && signal != moduleUpdatedSignal)
        return;

    auto *vehicle = check_and_cast<cModule *>(object);
    if (signal == moduleUpdatedSignal) {
        updateVehicleDisplay(vehicle);
        return;
    }
    // Correct the raw initial Veins display position before any network
    // configuration below can fail and stop the simulation at t=0.
    updateVehicleDisplay(vehicle);

    auto *configurator = check_and_cast<Ipv4NetworkConfigurator *>(
            getSystemModule()->getSubmodule("configurator"));

    // The original topology cache predates this vehicle. Rebuild it before
    // configuring the new interfaces and the routes that lead through them.
    configurator->computeConfiguration();
    configurator->configureAllInterfaces();
    configurator->configureAllRoutingTables();

    auto *positionSource = vehicle->getSubmodule("positionSource");
    auto positionAddress = L3AddressResolver().addressOf(positionSource);

    auto *binder = check_and_cast<simu5g::Binder *>(getSystemModule()->getSubmodule("binder"));
    simu5g::MacNodeId nodeId = simu5g::NODEID_NONE;
    for (const auto& entry : binder->getNodeInfoMap()) {
        if (entry.second.moduleRef.get() == vehicle && simu5g::isNrUe(entry.first)) {
            nodeId = entry.first;
            break;
        }
    }
    if (nodeId == simu5g::NODEID_NONE)
        throw cRuntimeError("No NR node ID registered for dynamic vehicle %s", vehicle->getFullPath().c_str());

    binder->setMacNodeId(positionAddress.toIpv4(), nodeId);
    EV_INFO << "Configured dynamic vehicle " << vehicle->getFullPath()
            << " and mapped position source " << positionAddress
            << " to NR node ID " << nodeId << endl;
}

void DynamicVehicleNetworkConfigurator::updateVehicleDisplay(cModule *vehicle)
{
    if (!hasGUI())
        return;

    auto *mobility = dynamic_cast<IMobility *>(vehicle->getSubmodule("mobility"));
    if (mobility == nullptr)
        return;

    const Coord position = mobility->getCurrentPosition();
    const double x = par("displayOffsetX").doubleValue() + par("displayScale").doubleValue() * position.x;
    const double y = par("displayOffsetY").doubleValue() + par("displayScale").doubleValue() * position.y;
    vehicle->getDisplayString().setTagArg("p", 0, x);
    vehicle->getDisplayString().setTagArg("p", 1, y);
}

} // namespace nasctime
