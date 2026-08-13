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

package nasctime.common;

import simu5g.stack.phy.channelmodel.NrChannelModel;

//
// NrChannelModel whose radio conditions can be changed while the run is in
// progress, without moving anything.
//
// In stock Simu5G, channel quality is a function of geometry. Path loss,
// shadowing and fading all come from the distance between the UE and the
// gNodeB, so degrading a link means walking the UE away from the cell, and
// every other channel-model parameter is copied into a C++ member during
// initialize() -- ScenarioManager's <set-param> changes the parameter and
// nothing reads it again. That makes "at t=2s the radio gets worse" awkward to
// express and slow to reach, because the UE has to travel first.
//
// This module adds the two parameters that were missing, reads them on every
// call instead of caching them, and marks them @mutable so a scenario script
// can set them directly:
//
//   <at t="2s">
//       <set-param module="gnb.cellularNic.phy.channelModel[0]"
//                  par="sinrOffset" value="15dB"/>
//   </at>
//
// Both parameters apply on top of the inherited model, so path loss, LOS and
// interference keep working exactly as before.
//
// Where to set it. The channel model that matters is the *receiver's*: uplink
// reception and uplink CQI feedback both run on the gNodeB's channel model
// (LtePhyEnb.cc:241 and LteRealisticChannelModel::isReceptionSuccessful), so
// an uplink study sets this on `gnb.cellularNic.phy.channelModel[0]` and a
// downlink one on `ue[*].cellularNic.phy.channelModel[0]`.
//
simple TunableNrChannelModel extends NrChannelModel
{
    parameters:
        @class(TunableNrChannelModel);

        // Subtracted from the SINR of every resource block, in dB. Positive
        // values make the link worse. This is the knob that behaves like a
        // real radio getting worse: the SINR feeds the CQI the gNodeB reports,
        // so the scheduler drops to a more robust MCS and needs more resource
        // blocks per packet, and it feeds the BLER table that decides whether
        // a transmission survives, so failed attempts are retransmitted by
        // HARQ. Latency and jitter rise before loss does; push it far enough
        // (the BLER table bottoms out below binder_->phyPisaData.minSnr()) and
        // the link stops carrying traffic altogether.
        volatile double sinrOffset @unit(dB) @mutable = default(0dB);

        // Probability that a transmission attempt is discarded regardless of
        // SINR, in [0,1]. Unlike sinrOffset this does not go through CQI, so
        // the scheduler never adapts to it -- use it to inject plain loss
        // (interference bursts, a jammer) with the modulation held fixed.
        // Drawn per attempt, so HARQ still retransmits what it drops.
        volatile double extraPer @mutable = default(0);

        // Which direction the impairment applies to. The gNodeB's channel
        // model computes SINR for both directions when a UE requests feedback,
        // so "UL" keeps an uplink study from perturbing the downlink.
        string impairedDirection @enum(UL,DL,BOTH) = default("BOTH");
}
