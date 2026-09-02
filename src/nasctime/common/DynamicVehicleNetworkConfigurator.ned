package nasctime.common;

// Keeps INET/Simu5G network state in sync with modules created by SUMO/Veins.
simple DynamicVehicleNetworkConfigurator
{
    parameters:
        @class(nasctime::DynamicVehicleNetworkConfigurator);
        double displayScale = default(5);
        double displayOffsetX = default(430);
        double displayOffsetY = default(100);
        @display("i=block/cogwheel");
}
