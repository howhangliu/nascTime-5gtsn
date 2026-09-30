#ifndef __NASCTIME_POSITIONREPORTERAPP_H
#define __NASCTIME_POSITIONREPORTERAPP_H

#include "inet/applications/udpapp/UdpBasicApp.h"

namespace nasctime {

// Sends a compact 20-byte vehicle state report:
// sequence, vehicle id, x [mm], y [mm], and speed [mm/s].
class PositionReporterApp : public inet::UdpBasicApp
{
  protected:
    virtual void sendPacket() override;
};

} // namespace nasctime

#endif
