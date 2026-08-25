package nasctime.simulations.demos.tas_comparison;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.tsn.TsnDevice;
import inet.node.tsn.TsnSwitch;
import nasctime.nodes.DsTt.DsTt;
import nasctime.nodes.DsTt.NRUeDsTt;
import nasctime.nodes.NwTt.NwTt;
import nasctime.nodes.TsnAf.TsnAf;
import ned.DatarateChannel;
import simu5g.common.binder.Binder;
import simu5g.common.carrierAggregation.CarrierAggregation;
import simu5g.nodes.Upf;
import simu5g.nodes.gNodeB;
import simu5g.world.radio.LteChannelControl;

// Compares ordinary FIFO forwarding with CNC-controlled TAS at the NW-TT and
// DS-TT TSN-facing Ethernet egress ports.
network TasComparisonNetwork
{
    parameters:
        @display("bgb=1450,500");

    types:
        channel Eth1G extends DatarateChannel {
            datarate = 1Gbps;
            delay = 0.1us;
        }
        channel Eth10G extends DatarateChannel {
            datarate = 10Gbps;
            delay = 0.1us;
        }
        channel Eth10M extends DatarateChannel {
            datarate = 10Mbps;
            delay = 0.1us;
        }

    submodules:
        channelControl: LteChannelControl { @display("p=50,50;is=s"); }
        routingRecorder: RoutingTableRecorder { @display("p=50,100;is=s"); }
        configurator: Ipv4NetworkConfigurator {
            @display("p=50,150;is=s");
            config = xmldoc("ip_config.xml");
        }
        binder: Binder { @display("p=50,200;is=s"); }
        carrierAggregation: CarrierAggregation { @display("p=50,250;is=s"); }
        tsnAf: TsnAf { @display("p=50,300;is=s"); }

        tsnDeviceA: TsnDevice { @display("p=150,400"); }
        tsnSwitch: TsnSwitch { @display("p=330,400"); }
        nwTt: NwTt {
            @display("p=510,400");
            ueAddress = "ue[0]";
            localAddress = "nwTt";
        }
        upf: Upf { @display("p=700,400"); }
        gnb: gNodeB { @display("p=880,400;is=vl"); }
        ue[1]: NRUeDsTt { @display("p=1040,400"); }
        dsTt: DsTt { @display("p=1190,400"); }
        tsnDeviceB: TsnDevice { @display("p=1360,400"); }

    connections:
        tsnDeviceA.ethg++ <--> Eth1G <--> tsnSwitch.ethg++;
        tsnSwitch.ethg++ <--> Eth1G <--> nwTt.tsnEthg;
        nwTt.filterGate <--> Eth10G <--> upf.dnPppg;
        upf.pppg++ <--> Eth10G <--> gnb.ppp;
        ue[0].ethg <--> Eth1G <--> dsTt.ueEthg;
        dsTt.tsnEthg <--> Eth10M <--> tsnDeviceB.ethg++;
}
