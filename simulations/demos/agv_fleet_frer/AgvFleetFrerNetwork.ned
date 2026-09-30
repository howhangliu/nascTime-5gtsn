package nasctime.simulations.demos.agv_fleet_frer;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.tsn.TsnDevice;
import nasctime.common.DynamicVehicleNetworkConfigurator;
import nasctime.nodes.NGNodeB;
import nasctime.nodes.NwTt.NwTt;
import nasctime.simulations.demos.sumo_closed_loop_frer.SumoFrerVehicle;
import ned.DatarateChannel;
import org.car2x.veins.subprojects.veins_inet.VeinsInetManager;
import simu5g.common.binder.Binder;
import simu5g.common.carrierAggregation.CarrierAggregation;
import simu5g.nodes.BackgroundCell;
import simu5g.nodes.Upf;
import simu5g.nodes.gNodeB;
import simu5g.world.radio.LteChannelControl;

// Buildsheet-based 100 m x 100 m AGV fleet. SUMO inserts exactly ten UEs:
// 3 centre-shuttle safety AGVs, 2 NW-loop AGVs, 2 SE-loop AGVs, 3 arms.
network AgvFleetFrerNetwork
{
    parameters:
        int numEndpoints = default(10);
        int numBgCells = default(0);
        // The logical floor is still 100 m x 100 m. Veins adds a 1 m margin
        // on each side to contain netconvert's centimetre-scale overshoot.
        double playgroundSizeX @unit(m) = default(110m);
        double playgroundSizeY @unit(m) = default(104m);
        double playgroundSizeZ @unit(m) = default(20m);
        @display("bgb=1160,760");
        @figure[area](type=rectangle; pos=440,105; size=500,500; lineColor=#b0bec5; lineWidth=2; fillColor=#fafafa; zIndex=-5);
        @figure[title](type=text; pos=690,72; text="AGV fleet - 100 m x 100 m"; anchor=s; font=Arial,15,bold; color=#263238);

        // 25 m grid matching columns A-E and rows 0-4 in the buildsheet.
        @figure[h0](type=line; points=440,605,940,605; lineColor=#cfd8dc; zIndex=-4);
        @figure[h1](type=line; points=440,480,940,480; lineColor=#cfd8dc; zIndex=-4);
        @figure[h2](type=line; points=440,355,940,355; lineColor=#cfd8dc; zIndex=-4);
        @figure[h3](type=line; points=440,230,940,230; lineColor=#cfd8dc; zIndex=-4);
        @figure[h4](type=line; points=440,105,940,105; lineColor=#cfd8dc; zIndex=-4);
        @figure[v0](type=line; points=440,105,440,605; lineColor=#cfd8dc; zIndex=-4);
        @figure[v1](type=line; points=565,105,565,605; lineColor=#cfd8dc; zIndex=-4);
        @figure[v2](type=line; points=690,105,690,605; lineColor=#cfd8dc; zIndex=-4);
        @figure[v3](type=line; points=815,105,815,605; lineColor=#cfd8dc; zIndex=-4);
        @figure[v4](type=line; points=940,105,940,605; lineColor=#cfd8dc; zIndex=-4);

        @figure[nw](type=rectangle; pos=440,105; size=125,250; lineColor=#1565c0; lineWidth=3; lineStyle=dashed; fillOpacity=0; zIndex=-2);
        @figure[nwLabel](type=text; pos=502,145; text="Loop NW\n2 UEs"; anchor=n; font=Arial,13,bold; color=#1565c0);
        @figure[se](type=rectangle; pos=815,355; size=125,250; lineColor=#1565c0; lineWidth=3; lineStyle=dashed; fillOpacity=0; zIndex=-2);
        @figure[seLabel](type=text; pos=877,565; text="Loop SE\n2 UEs"; anchor=s; font=Arial,13,bold; color=#1565c0);
        @figure[shuttleBand](type=rectangle; pos=670,105; size=40,500; lineOpacity=0; fillColor=#ef9a9a; fillOpacity=0.25; zIndex=-3);
        @figure[shuttle](type=line; points=690,105,690,605; lineColor=#b71c1c; lineWidth=4; zIndex=-2);
        @figure[shuttleLabel](type=text; pos=735,175; text="Centre shuttle - 3 UEs"; anchor=w; font=Arial,13,bold; color=#b71c1c);
        @figure[workcell](type=rectangle; pos=615,530; size=90,50; lineColor=#00695c; lineWidth=2; fillColor=#b2dfdb; fillOpacity=0.45; zIndex=-2);
        @figure[workcellLabel](type=text; pos=660,585; text="workcell - 3 UEs"; anchor=n; font=Arial,12; color=#00695c);
        @figure[colLabels](type=text; pos=690,630; text="A             B             C             D             E"; anchor=n; font=Courier New,12; color=#546e7a);
        @figure[gnb1Label](type=text; pos=455,335; text="gNB1 (0, 50, 8)"; anchor=sw; font=Arial,11,bold; color=#263238);
        @figure[gnb2Label](type=text; pos=925,335; text="gNB2 (100, 50, 8)"; anchor=se; font=Arial,11,bold; color=#263238);

    types:
        channel Eth1G extends DatarateChannel { datarate = 1Gbps; delay = 0.1us; }
        channel Eth10G extends DatarateChannel { datarate = 10Gbps; delay = 0.1us; }

    submodules:
        channelControl: LteChannelControl { @display("p=40,30;is=s"); }
        routingRecorder: RoutingTableRecorder { @display("p=40,70;is=s"); }
        configurator: Ipv4NetworkConfigurator { config = xmldoc("../sumo_closed_loop_frer/ip_config.xml"); @display("p=40,110;is=s"); }
        binder: Binder { @display("p=40,150;is=s"); }
        carrierAggregation: CarrierAggregation { @display("p=40,190;is=s"); }
        veinsManager: VeinsInetManager { @display("p=40,230;is=s"); }
        dynamicConfigurator: DynamicVehicleNetworkConfigurator {
            displayScale = 5;
            // Veins already flips SUMO Y into the OMNeT++ coordinate system.
            // Remove the 1 m TraCI margin before applying the 5x display scale.
            // The padding boundary starts at (-1,-1); together with the 1 m
            // TraCI margin, driven coordinate (0,100) maps to canvas (440,105).
            displayOffsetX = 430;
            displayOffsetY = 95;
            displayInvertY = false;
            displayHeight = 500;
            @display("p=40,270;is=s");
        }
        tsnServer: TsnDevice { @display("p=105,435;i=device/server"); }
        nwTt: NwTt { ueAddress = "nwTt"; localAddress = "nwTt"; @display("p=225,435"); }
        upf: Upf { @display("p=345,365"); }
        upf2: Upf { @display("p=345,515"); }
        gnb: NGNodeB { @display("p=440,355;is=vl"); }
        gnb2: gNodeB { @display("p=940,355;is=vl"); }
        bgCell[numBgCells]: BackgroundCell { @display("p=1040,180;is=s"); }
        car[0]: SumoFrerVehicle;

    connections allowunconnected:
        tsnServer.ethg++ <--> Eth1G <--> nwTt.tsnEthg;
        nwTt.filterGate <--> Eth10G <--> upf.dnPppg;
        upf.pppg++ <--> Eth10G <--> gnb.ppp;
        nwTt.filterGate2 <--> Eth10G <--> upf2.dnPppg;
        upf2.pppg++ <--> Eth10G <--> gnb2.ppp;
}
