package nasctime.simulations.demos.sumo_nr;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.ethernet.Eth10G;
import inet.node.inet.Router;
import inet.node.inet.StandardHost;
import nasctime.common.MobilityCsvRecorder;
import org.car2x.veins.subprojects.veins_inet.VeinsInetManager;
import simu5g.common.binder.Binder;
import simu5g.common.carrierAggregation.CarrierAggregation;
import simu5g.nodes.NrCar;
import simu5g.nodes.Upf;
import simu5g.nodes.gNodeB;
import simu5g.world.radio.LteChannelControl;

// Minimal SUMO-backed NR scenario: one dynamically created car sends UDP
// traffic through one gNB to a fixed server.
network SumoNrNetwork
{
    parameters:
        double playgroundSizeX @unit(m) = default(1200m);
        double playgroundSizeY @unit(m) = default(300m);
        double playgroundSizeZ @unit(m) = default(50m);
        @display("bgb=1200,300");

    submodules:
        channelControl: LteChannelControl {
            @display("p=40,30;is=s");
        }
        routingRecorder: RoutingTableRecorder {
            @display("p=40,70;is=s");
        }
        configurator: Ipv4NetworkConfigurator {
            config = xmldoc("ip_config.xml");
            @display("p=40,110;is=s");
        }
        binder: Binder {
            @display("p=40,150;is=s");
        }
        carrierAggregation: CarrierAggregation {
            @display("p=40,190;is=s");
        }
        veinsManager: VeinsInetManager {
            @display("p=40,230;is=s");
        }
        mobilityRecorder: MobilityCsvRecorder {
            nodePath = "car[0]";
            @display("p=40,270;is=s");
        }

        server: StandardHost {
            @display("p=1080,70;i=device/server");
        }
        router: Router {
            @display("p=900,70;i=device/smallrouter");
        }
        upf: Upf {
            @display("p=720,70");
        }
        gnb: gNodeB {
            @display("p=600,180;is=vl");
        }

        // VeinsInetManager grows this vector as SUMO vehicles depart.
        car[0]: NrCar;

    connections allowunconnected:
        server.pppg++ <--> Eth10G <--> router.pppg++;
        router.pppg++ <--> Eth10G <--> upf.dnPppg;
        upf.pppg++ <--> Eth10G <--> gnb.ppp;
}
