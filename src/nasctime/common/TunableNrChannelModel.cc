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

#include "nasctime/common/TunableNrChannelModel.h"

#include <inet/common/InitStages.h>

Define_Module(TunableNrChannelModel);

void TunableNrChannelModel::initialize(int stage)
{
    simu5g::NrChannelModel::initialize(stage);

    if (stage == inet::INITSTAGE_LOCAL) {
        const char *dir = par("impairedDirection");
        if (!strcmp(dir, "UL"))
            impairedDirection_ = IMPAIR_UL;
        else if (!strcmp(dir, "DL"))
            impairedDirection_ = IMPAIR_DL;
        else if (!strcmp(dir, "BOTH"))
            impairedDirection_ = IMPAIR_BOTH;
        else
            throw cRuntimeError("Unknown impairedDirection '%s', expected UL, DL or BOTH", dir);
    }
}

bool TunableNrChannelModel::impairs(const simu5g::UserControlInfo *lteInfo) const
{
    simu5g::Direction dir = lteInfo->getDirection();
    switch (impairedDirection_) {
        case IMPAIR_UL: if (dir != simu5g::UL) return false; break;
        case IMPAIR_DL: if (dir != simu5g::DL) return false; break;
        default: break;
    }

    int impairedNodeId = par("impairedNodeId").intValue();
    if (impairedNodeId < 0)
        return true;

    // In Simu5G's feedback and uplink-reception paths, sourceId is the UE.
    // For an ordinary downlink data frame, the UE is the destination instead.
    simu5g::MacNodeId ueId =
            (dir == simu5g::DL && lteInfo->getFrameType() != simu5g::FEEDBACKPKT)
            ? lteInfo->getDestId() : lteInfo->getSourceId();
    return ueId == static_cast<simu5g::MacNodeId>(impairedNodeId);
}

std::vector<double> TunableNrChannelModel::getSINR(simu5g::LteAirFrame *frame, simu5g::UserControlInfo *lteInfo)
{
    std::vector<double> snrV = simu5g::NrChannelModel::getSINR(frame, lteInfo);

    if (!impairs(lteInfo))
        return snrV;

    double offset = par("sinrOffset").doubleValue();
    if (offset == 0.0)
        return snrV;

    // The inherited SINR is in dB, so the offset is a subtraction rather than
    // a division: 10dB of offset is 10dB less signal on every resource block.
    for (double& snr : snrV)
        snr -= offset;

    return snrV;
}

bool TunableNrChannelModel::isReceptionSuccessful(simu5g::LteAirFrame *frame, simu5g::UserControlInfo *lteInfo)
{
    if (!simu5g::NrChannelModel::isReceptionSuccessful(frame, lteInfo))
        return false;

    if (!impairs(lteInfo))
        return true;

    double per = par("extraPer").doubleValue();
    if (per <= 0.0)
        return true;
    if (per > 1.0)
        throw cRuntimeError("Invalid extraPer %g, must be in [0,1]", per);

    // Drawn per transmission attempt, i.e. before HARQ. A lost attempt is
    // retransmitted like any other, so this raises latency first and only
    // shows up as end-to-end loss once the HARQ attempts run out.
    return uniform(0.0, 1.0) > per;
}
