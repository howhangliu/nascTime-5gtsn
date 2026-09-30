package nasctime.simulations.demos.tsn_standalone;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.node.tsn.TsnDevice;
import inet.node.tsn.TsnSwitch;
import nasctime.nodes.TsnAf.TsnAf;
import ned.DatarateChannel;

//
// The TAS comparison without the 5G bridge: two senders share one switch and
// one congested egress port toward the receiver.
//
// This is the control experiment for tas_comparison's TasComparisonNetwork.
// There, the critical and best-effort streams meet at the DS-TT's 10 Mbps
// TSN-facing port, after crossing the 5GS. Here they meet at the switch's own
// 10 Mbps port toward tsnDeviceC, with nothing else in the path -- so the same
// gate control list acts on the same contention, and the difference between
// the two scenarios is the 5G leg rather than the shaper.
//
network TsnStandaloneNetwork
{
    parameters:
        @display("bgb=900,300");

    types:
        channel Eth1G extends DatarateChannel {
            datarate = 1Gbps;
            delay = 0.1us;
        }
        channel Eth10M extends DatarateChannel {
            datarate = 10Mbps;
            delay = 0.1us;
        }

    submodules:
        configurator: Ipv4NetworkConfigurator {
            @display("p=60,60;is=s");
            config = xmldoc("ip_config.xml");
        }
        tsnAf: TsnAf { @display("p=60,140;is=s"); }

        // tsnDeviceA carries the critical stream and tsnDeviceB the background
        // load, matching the two applications tsnDeviceA runs in the 5G-TSN
        // scenario. Splitting them across two senders is what makes this a
        // switch contention experiment rather than a single-egress one.
        tsnDeviceA: TsnDevice { @display("p=220,100"); }
        tsnDeviceB: TsnDevice { @display("p=220,220"); }
        tsnSwitch: TsnSwitch { @display("p=430,160"); }
        tsnDeviceC: TsnDevice { @display("p=650,160"); }

    connections:
        // Connection order fixes the switch's port numbering: eth0 -> A,
        // eth1 -> B, eth2 -> C. The gate control list is applied to eth2.
        tsnDeviceA.ethg++ <--> Eth1G <--> tsnSwitch.ethg++;
        tsnDeviceB.ethg++ <--> Eth1G <--> tsnSwitch.ethg++;
        tsnSwitch.ethg++ <--> Eth10M <--> tsnDeviceC.ethg++;
}
