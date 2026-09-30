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

#include "nasctime/nodes/TsnAf/TsnAf.h"

#include <inet/common/XMLUtils.h>
#include <omnetpp/cvaluearray.h>

#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <cstring>

Define_Module(TsnAf);

namespace {

// A pure-TSN deployment has no 5GS for the AF to reference, so an empty path
// means "this component is not present" and leaves the pointer null. A
// non-empty path that does not resolve stays an error: getModuleByPath()
// throws on a typo, and losing that would turn a misspelled module name into a
// silently unconfigured bridge.
cModule *findOptionalModule(cModule *context, const char *path, const char *role)
{
    if (path == nullptr || *path == '\0')
        return nullptr;
    cModule *module = context->findModuleByPath(path);
    if (module == nullptr)
        throw cRuntimeError("TsnAf: %s module '%s' was not found", role, path);
    return module;
}

}  // namespace

void TsnAf::initialize(int stage)
{
    cSimpleModule::initialize(stage);

    if (stage == INITSTAGE_LOCAL) {
        portSpeedBps = par("portSpeedBps");
        numTrafficClasses = par("numTrafficClasses");

        // Parse PCP-to-QFI mapping
        std::string mapStr = par("pcpToQfiMap").stdstringValue();
        cStringTokenizer tokenizer(mapStr.c_str(), ",");
        while (tokenizer.hasMoreTokens())
            pcpToQfi.push_back(atoi(tokenizer.nextToken()));
        while (pcpToQfi.size() < 8)
            pcpToQfi.push_back(pcpToQfi.size());  // default: PCP = QFI

        bridgeDelayUpdatedSignal = registerSignal("bridgeDelayUpdated");
        streamConfiguredSignal = registerSignal("streamConfigured");
        qosViolationSignal = registerSignal("qosViolation");

        EV_INFO << "TsnAf: initialized with " << numTrafficClasses
                << " traffic classes, port speed " << portSpeedBps / 1e9 << " Gbps" << endl;
    }
    else if (stage == INITSTAGE_APPLICATION_LAYER) {
        // Find bridge modules. All three are optional: the standalone TSN
        // scenario reuses this module purely to program a switch's shaper.
        nwTtModule = findOptionalModule(this, par("nwTtModule").stringValue(), "NW-TT");
        dsTtModule = findOptionalModule(this, par("dsTtModule").stringValue(), "DS-TT");
        gnbModule = findOptionalModule(this, par("gnbModule").stringValue(), "gNB");

        // Subscribe to DS-TT residence time signal
        if (dsTtModule) {
            auto *translator = dsTtModule->getSubmodule("translator");
            if (translator) {
                simsignal_t residenceSignal = registerSignal("residenceTime");
                translator->subscribe("residenceTime", this);
                EV_INFO << "TsnAf: subscribed to DS-TT residence time signal" << endl;
            }
        }

        // Load CNC configuration
        cXMLElement *xmlConfig = par("cncConfig").xmlValue();
        if (xmlConfig && xmlConfig->getFirstChild()) {
            loadCncConfig(xmlConfig);
        } else {
            EV_INFO << "TsnAf: no CNC config provided, using defaults" << endl;
        }
    }
}

void TsnAf::handleMessage(cMessage *msg)
{
    delete msg;  // no self-messages expected for now
}

void TsnAf::receiveSignal(cComponent *source, simsignal_t signalID,
                           const simtime_t& t, cObject *details)
{
    // Update bridge delay statistics from DS-TT residence time
    simtime_t delay = t;
    if (delay < delayMin) delayMin = delay;
    if (delay > delayMax) delayMax = delay;
    delaySum += delay;
    delaySamples++;

    emit(bridgeDelayUpdatedSignal, delay);

    // Update published parameters so other modules can read them
    par("bridgeDelayMin") = delayMin.dbl();
    par("bridgeDelayMax") = delayMax.dbl();
    par("bridgeDelayAvg") = (delaySum / delaySamples).dbl();

    // Check for QoS violations against stream reservations
    for (const auto& sr : streamReservations) {
        if (sr.maxLatencyMs > 0 && delay.dbl() * 1000 > sr.maxLatencyMs) {
            EV_WARN << "TsnAf: QoS VIOLATION — stream " << sr.streamId
                    << " delay " << delay.dbl() * 1000 << "ms exceeds max "
                    << sr.maxLatencyMs << "ms" << endl;
            emit(qosViolationSignal, (long)sr.streamId);
        }
    }
}

void TsnAf::loadCncConfig(cXMLElement *xmlConfig)
{
    EV_INFO << "TsnAf: loading CNC configuration" << endl;

    // Parse stream reservations
    cXMLElement *streamsElem = xmlConfig->getFirstChildWithTag("streams");
    if (streamsElem)
        parseStreamReservations(streamsElem);

    // Parse TAS gate control list
    cXMLElement *tasElem = xmlConfig->getFirstChildWithTag("gateControlList");
    if (tasElem)
        parseGateControlList(tasElem);

    // Apply configurations
    applyStreamReservations();
    applyGateControlList();
}

void TsnAf::parseStreamReservations(cXMLElement *streamsElem)
{
    cXMLElementList streamList = streamsElem->getChildrenByTagName("stream");
    for (auto *streamElem : streamList) {
        StreamReservation sr;
        sr.streamId = atoi(streamElem->getAttribute("id"));
        sr.pcp = atoi(streamElem->getAttribute("pcp"));
        sr.qfi = (sr.pcp < (int)pcpToQfi.size()) ? pcpToQfi[sr.pcp] : sr.pcp;
        sr.drbIndex = atoi(streamElem->getAttribute("drb"));
        sr.maxLatencyMs = atof(streamElem->getAttribute("maxLatencyMs"));
        sr.reservedBandwidthKbps = atof(streamElem->getAttribute("bandwidthKbps"));

        streamReservations.push_back(sr);
        emit(streamConfiguredSignal, (long)sr.streamId);

        EV_INFO << "TsnAf: stream " << sr.streamId
                << " PCP=" << sr.pcp << " QFI=" << sr.qfi
                << " DRB=" << sr.drbIndex
                << " maxLatency=" << sr.maxLatencyMs << "ms"
                << " bandwidth=" << sr.reservedBandwidthKbps << "kbps" << endl;
    }
}

void TsnAf::parseGateControlList(cXMLElement *tasElem)
{
    const char *cycleStr = tasElem->getAttribute("cycleTime");
    gateCycleTime = cycleStr ? SimTime::parse(cycleStr) : SimTime(1, SIMTIME_MS);

    cXMLElementList entries = tasElem->getChildrenByTagName("entry");
    for (auto *entryElem : entries) {
        const char *start = entryElem->getAttribute("start");
        const char *duration = entryElem->getAttribute("duration");
        const char *gates = entryElem->getAttribute("gates");
        if (!start || !duration || !gates)
            throw cRuntimeError("TsnAf: every gateControlList entry must have start, duration, and gates attributes");

        GateControlEntry gce;
        gce.startTime = SimTime::parse(start);
        gce.duration = SimTime::parse(duration);
        char *end = nullptr;
        errno = 0;
        long gateStates = strtol(gates, &end, 0);
        if (gce.duration <= SIMTIME_ZERO)
            throw cRuntimeError("TsnAf: GCL entry at %s has a non-positive duration", start);
        if (errno != 0 || end == gates || *end != '\0' || gateStates < 0 || gateStates > 255)
            throw cRuntimeError("TsnAf: invalid 8-bit GCL gate bitmask '%s'", gates);
        gce.gateStates = static_cast<uint8_t>(gateStates);

        gateControlList.push_back(gce);

        EV_INFO << "TsnAf: TAS entry start=" << gce.startTime
                << " duration=" << gce.duration
                << " gates=0x" << std::hex << (int)gce.gateStates << std::dec << endl;
    }

    EV_INFO << "TsnAf: loaded " << gateControlList.size()
            << " TAS entries, cycle=" << gateCycleTime << endl;
}

void TsnAf::applyStreamReservations()
{
    // Log the configuration that would be applied
    // In a full implementation, this would programmatically set
    // the gNB SDAP drbConfig and MAC scheduler parameters
    EV_INFO << "TsnAf: applying " << streamReservations.size()
            << " stream reservations" << endl;

    for (const auto& sr : streamReservations) {
        EV_INFO << "TsnAf: stream " << sr.streamId
                << " → DRB " << sr.drbIndex
                << " (QFI=" << sr.qfi << ")" << endl;
    }
}

void TsnAf::applyGateControlList()
{
    if (gateControlList.empty())
        return;

    if (gateCycleTime <= SIMTIME_ZERO)
        throw cRuntimeError("TsnAf: gate cycle time must be positive");
    if (numTrafficClasses < 1 || numTrafficClasses > 8)
        throw cRuntimeError("TsnAf: TAS supports between 1 and 8 traffic classes, got %d", numTrafficClasses);

    std::sort(gateControlList.begin(), gateControlList.end(),
            [](const GateControlEntry& a, const GateControlEntry& b) { return a.startTime < b.startTime; });
    simtime_t expectedStart = SIMTIME_ZERO;
    for (const auto& entry : gateControlList) {
        if (entry.startTime != expectedStart)
            throw cRuntimeError("TsnAf: GCL must cover the cycle contiguously; expected an entry at %s but found %s",
                    expectedStart.str().c_str(), entry.startTime.str().c_str());
        expectedStart += entry.duration;
    }
    if (expectedStart != gateCycleTime)
        throw cRuntimeError("TsnAf: GCL entries cover %s but cycleTime is %s",
                expectedStart.str().c_str(), gateCycleTime.str().c_str());

    int configuredShapers = 0;
    cStringTokenizer shaperPaths(par("tasShaperModules").stringValue(), ",");
    while (shaperPaths.hasMoreTokens()) {
        const char *shaperPath = shaperPaths.nextToken();
        cModule *shaper = getModuleByPath(shaperPath);
        if (!shaper)
            throw cRuntimeError("TsnAf: TAS shaper module '%s' was not found", shaperPath);
        if (!shaper || strcmp(shaper->getNedTypeName(), "inet.linklayer.ieee8021q.Ieee8021qTimeAwareShaper") != 0)
            throw cRuntimeError("TsnAf: %s is not an Ieee8021qTimeAwareShaper; enable egress traffic shaping on the TT",
                    shaper->getFullPath().c_str());

        int gateCount = shaper->getSubmoduleVectorSize("transmissionGate");
        if (gateCount != numTrafficClasses)
            throw cRuntimeError("TsnAf: %s has %d transmission gates but TsnAf numTrafficClasses is %d",
                    shaper->getFullPath().c_str(), gateCount, numTrafficClasses);

        for (int gateIndex = 0; gateIndex < gateCount; ++gateIndex) {
            cModule *gate = shaper->getSubmodule("transmissionGate", gateIndex);
            if (!gate || strcmp(gate->getNedTypeName(), "inet.queueing.gate.PeriodicGate") != 0)
                throw cRuntimeError("TsnAf: transmissionGate[%d] in %s is not a PeriodicGate",
                        gateIndex, shaper->getFullPath().c_str());

            bool initiallyOpen = (gateControlList.front().gateStates & (1u << gateIndex)) != 0;
            bool currentState = initiallyOpen;
            double currentDuration = 0;
            double trailingDuration = 0;
            auto *durations = new cValueArray();

            // PeriodicGate alternates state after each duration. Coalesce
            // adjacent GCL entries with the same state, then merge a final
            // run into the first when the state is unchanged across the
            // cycle boundary. The offset keeps time zero at the GCL origin.
            for (const auto& entry : gateControlList) {
                bool entryState = (entry.gateStates & (1u << gateIndex)) != 0;
                if (entryState != currentState) {
                    durations->add(cValue(currentDuration, "s"));
                    currentState = entryState;
                    currentDuration = 0;
                }
                currentDuration += entry.duration.dbl();
            }

            if (durations->size() % 2 != 0)
                durations->add(cValue(currentDuration, "s"));
            else if (durations->size() != 0) {
                trailingDuration = currentDuration;
                durations->set(0, cValue(durations->get(0).doubleValueInUnit("s") + trailingDuration, "s"));
            }

            cPar& durationsParameter = gate->par("durations");
            durationsParameter.copyIfShared();
            durationsParameter.setObjectValue(durations);
            gate->par("initiallyOpen").setBoolValue(initiallyOpen);
            gate->par("offset").setDoubleValue(trailingDuration);
        }

        configuredShapers++;
        EV_INFO << "TsnAf: applied " << gateControlList.size() << " GCL entries to "
                << shaper->getFullPath() << " (cycle=" << gateCycleTime << ")" << endl;
    }

    if (configuredShapers == 0)
        throw cRuntimeError("TsnAf: tasShaperModules does not contain any module paths");
}

int TsnAf::getQfiForPcp(int pcp) const
{
    if (pcp >= 0 && pcp < (int)pcpToQfi.size())
        return pcpToQfi[pcp];
    return pcp;
}

int TsnAf::getPcpForQfi(int qfi) const
{
    for (int i = 0; i < (int)pcpToQfi.size(); i++) {
        if (pcpToQfi[i] == qfi)
            return i;
    }
    return qfi;
}

simtime_t TsnAf::getBridgeDelayAvg() const
{
    if (delaySamples == 0)
        return SIMTIME_ZERO;
    return delaySum / delaySamples;
}

void TsnAf::finish()
{
    EV_INFO << "TsnAf: Bridge delay stats —"
            << " min=" << delayMin.inUnit(SIMTIME_MS) << "ms"
            << " max=" << delayMax.inUnit(SIMTIME_MS) << "ms"
            << " avg=" << getBridgeDelayAvg().inUnit(SIMTIME_MS) << "ms"
            << " samples=" << delaySamples << endl;

    EV_INFO << "TsnAf: " << streamReservations.size()
            << " stream reservations configured" << endl;
}
