package nasctime.simulations.demos.sumo_closed_loop_frer;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.tsn.TsnDevice;
import nasctime.common.DynamicVehicleNetworkConfigurator;
import nasctime.nodes.NGNodeB;
import nasctime.nodes.NwTt.NwTt;
import ned.DatarateChannel;
import org.car2x.veins.subprojects.veins_inet.VeinsInetManager;
import simu5g.common.binder.Binder;
import simu5g.common.carrierAggregation.CarrierAggregation;
import simu5g.nodes.Upf;
import simu5g.nodes.gNodeB;
import simu5g.world.radio.LteChannelControl;

// Partial-overlap variant: two 70 m availability circles centered at
// (15,50) and (85,50). Their union covers the 100 m square, while only the
// lens-shaped middle region can carry both FRER copies simultaneously.
network SumoPartialOverlapFrerNetwork
{
    parameters:
        int numEndpoints = default(10);
        bool frerInterSession = default(true);
        bool frerDualConn = default(true);
        double playgroundSizeX @unit(m) = default(100m);
        double playgroundSizeY @unit(m) = default(100m);
        double playgroundSizeZ @unit(m) = default(20m);
        @display("bgb=1250,700");
        @figure[primaryCoverage](type=oval; pos=155,0; size=700,700; lineColor=#1565c0; lineWidth=2; fillColor=#90caf9; fillOpacity=0.12; zIndex=-5);
        @figure[replicaCoverage](type=oval; pos=505,0; size=700,700; lineColor=#ef6c00; lineWidth=2; fillColor=#ffcc80; fillOpacity=0.12; zIndex=-4);
        @figure[serviceArea](type=rectangle; pos=430,100; size=500,500; lineColor=#607d8b; lineWidth=2; fillColor=#e8f5e9; fillOpacity=0.25; zIndex=-3);
        @figure[serviceAreaLabel](type=text; pos=680,82; text="100 m x 100 m: left-only / overlap / right-only"; anchor=s; font=Arial,14,bold; color=#37474f);
        @figure[roadH0](type=rectangle; pos=430,98; size=500,4; lineColor=#78909c; fillColor=#78909c; zIndex=-2);
        @figure[roadH1](type=rectangle; pos=430,348; size=500,4; lineColor=#78909c; fillColor=#78909c; zIndex=-2);
        @figure[roadH2](type=rectangle; pos=430,598; size=500,4; lineColor=#78909c; fillColor=#78909c; zIndex=-2);
        @figure[roadV0](type=rectangle; pos=428,100; size=4,500; lineColor=#78909c; fillColor=#78909c; zIndex=-2);
        @figure[roadV1](type=rectangle; pos=678,100; size=4,500; lineColor=#78909c; fillColor=#78909c; zIndex=-2);
        @figure[roadV2](type=rectangle; pos=928,100; size=4,500; lineColor=#78909c; fillColor=#78909c; zIndex=-2);

    types:
        channel Eth1G extends DatarateChannel { datarate = 1Gbps; delay = 0.1us; }
        channel Eth10G extends DatarateChannel { datarate = 10Gbps; delay = 0.1us; }

    submodules:
        channelControl: LteChannelControl { @display("p=40,30;is=s"); }
        routingRecorder: RoutingTableRecorder { @display("p=40,70;is=s"); }
        configurator: Ipv4NetworkConfigurator {
            config = xmldoc("ip_config.xml");
            @display("p=40,110;is=s");
        }
        binder: Binder { @display("p=40,150;is=s"); }
        carrierAggregation: CarrierAggregation { @display("p=40,190;is=s"); }
        veinsManager: VeinsInetManager { @display("p=40,230;is=s"); }
        dynamicConfigurator: DynamicVehicleNetworkConfigurator {
            displayScale = 5;
            displayOffsetX = 430;
            displayOffsetY = 100;
            @display("p=40,270;is=s");
        }

        tsnServer: TsnDevice { @display("p=100,430;i=device/server"); }
        nwTt: NwTt {
            ueAddress = "nwTt";
            localAddress = "nwTt";
            @display("p=220,430");
        }
        upf: Upf { @display("p=350,350"); }
        upf2: Upf { @display("p=350,510"); }
        gnb: NGNodeB { @display("p=505,350;is=vl"); }
        gnb2: gNodeB { @display("p=855,350;is=vl"); }

        car[0]: SumoFrerVehicle;

    connections allowunconnected:
        tsnServer.ethg++ <--> Eth1G <--> nwTt.tsnEthg;
        nwTt.filterGate <--> Eth10G <--> upf.dnPppg;
        upf.pppg++ <--> Eth10G <--> gnb.ppp;
        nwTt.filterGate2 <--> Eth10G <--> upf2.dnPppg;
        upf2.pppg++ <--> Eth10G <--> gnb2.ppp;
}
