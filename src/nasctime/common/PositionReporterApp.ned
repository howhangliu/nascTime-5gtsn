package nasctime.common;

import inet.applications.udpapp.UdpBasicApp;

// UDP source whose fixed 20-byte payload contains the vehicle's current state.
simple PositionReporterApp extends UdpBasicApp
{
    parameters:
        @class(nasctime::PositionReporterApp);
        string mobilityModule;
        messageLength = default(20B);
        packetName = default("positionReport");
}
