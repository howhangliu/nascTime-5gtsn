//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
// 
// You should have received a copy of the GNU Lesser General Public License
// along with this program.  If not, see http://www.gnu.org/licenses/.
// 

#ifndef __SIMU5G_1_4_1_SDAP_STATICBMCA_H_
#define __SIMU5G_1_4_1_SDAP_STATICBMCA_H_

#include <omnetpp.h>
#include <inet/common/InitStages.h>
#include <map>
#include <vector>
#include <string>

using namespace omnetpp;

enum class GptpRole {
    MASTER,
    BRIDGE,
    SLAVE,
    TRANSPARENT  // 5GS bridge
};

struct SpanningTreeEntry {
    std::string moduleName;
    GptpRole role;
    std::vector<std::string> masterPorts;
    std::string slavePort;
};

struct GrandmasterInfo {
    std::string moduleName;
    int priority1;
    int priority2;
    int clockClass;
    int clockAccuracy;
    int offsetScaledLogVariance;
};

class StaticBmca : public cSimpleModule
{
  protected:
    GrandmasterInfo grandmaster;
    std::vector<SpanningTreeEntry> spanningTree;
    std::map<std::string, SpanningTreeEntry*> nodeRoleMap;

    bool transparentClockEnabled;
    bool correctionFieldSupport;

    simsignal_t bmcaEstablishedSignal;
    simsignal_t bmcaValidationErrorSignal;

    int validationErrors = 0;

  protected:
    virtual void initialize(int stage) override;
    virtual int numInitStages() const override { return inet::NUM_INIT_STAGES; }
    virtual void handleMessage(cMessage *msg) override;
    virtual void finish() override;

    void loadSpanningTree();
    void validateTopology();
    GptpRole parseRole(const std::string& roleStr);
    std::string roleToString(GptpRole role);

  public:
    // API for other modules
    const GrandmasterInfo& getGrandmasterInfo() const { return grandmaster; }
    GptpRole getNodeRole(const std::string& moduleName) const;
    bool isTransparentClock(const std::string& moduleName) const;
    bool hasGrandmaster() const { return !grandmaster.moduleName.empty(); }
    const std::vector<SpanningTreeEntry>& getSpanningTree() const { return spanningTree; }
};

#endif
