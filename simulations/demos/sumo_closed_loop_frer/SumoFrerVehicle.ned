package nasctime.simulations.demos.sumo_closed_loop_frer;

import inet.linklayer.ethernet.basic.EthernetInterface;
import inet.node.tsn.TsnDevice;
import nasctime.nodes.DsTt.DsTt;
import ned.DatarateChannel;
import simu5g.nodes.NrUe;

// Dynamically instantiated by VeinsInetManager for every SUMO vehicle.
// The reporting TSN device and DS-TT travel with the radio UE.
module SumoFrerVehicle extends NrUe
{
    parameters:
        numEthInterfaces = default(1);
        eth[*].typename = default("EthernetInterface");
        encap.typename = default("EthernetEncapsulation");
        @display("i=vehicle/car;bgb=420,260");

    types:
        channel Eth1G extends DatarateChannel
        {
            datarate = 1Gbps;
            delay = 0.1us;
        }

    submodules:
        dsTt: DsTt {
            @display("p=210,185;i=abstract/switch");
        }
        positionSource: TsnDevice {
            @display("p=340,185;i=device/sensor");
        }

    connections:
        eth[0].phys <--> Eth1G <--> dsTt.ueEthg;
        dsTt.tsnEthg <--> Eth1G <--> positionSource.ethg++;
}
