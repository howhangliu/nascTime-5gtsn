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

#ifndef __NASCTIME_COMMON_TUNABLENRCHANNELMODEL_H_
#define __NASCTIME_COMMON_TUNABLENRCHANNELMODEL_H_

#include <simu5g/stack/phy/channelmodel/NrChannelModel.h>

//
// NrChannelModel with two knobs that can be turned while the simulation runs.
//
// Simu5G's channel models take their radio conditions from geometry: the only
// way to make a link worse is to move the UE away from the gNodeB, and every
// other knob is cached into a C++ member during initialize(), so
// ScenarioManager's <set-param> has no effect on it. This subclass adds the
// two parameters the model was missing, reads them on every call rather than
// caching them, and marks them @mutable so a scenario script can set them.
//
// See TunableNrChannelModel.ned for what the parameters mean.
//
class TunableNrChannelModel : public simu5g::NrChannelModel
{
  protected:
    // Which traffic direction the impairment applies to. The gNodeB's channel
    // model computes SINR for both directions -- uplink on reception, and both
    // uplink and downlink when a UE asks for feedback -- so an uplink study
    // wants to leave downlink alone.
    enum ImpairedDirection { IMPAIR_UL, IMPAIR_DL, IMPAIR_BOTH };
    ImpairedDirection impairedDirection_ = IMPAIR_BOTH;

    bool impairs(const simu5g::UserControlInfo *lteInfo) const;

  public:
    void initialize(int stage) override;

    // Returns the inherited per-band SINR with `sinrOffset` subtracted. This
    // is the only place SINR enters the model, so the offset reaches both the
    // CQI the gNodeB feeds back and the BLER lookup that decides whether a
    // transmission is received.
    std::vector<double> getSINR(simu5g::LteAirFrame *frame, simu5g::UserControlInfo *lteInfo) override;

    // Inherited reception outcome, with an independent `extraPer` draw on top.
    bool isReceptionSuccessful(simu5g::LteAirFrame *frame, simu5g::UserControlInfo *lteInfo) override;
};

#endif
