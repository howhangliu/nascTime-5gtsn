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

package nasctime.simulations.demos.uplink_test;

import nasctime.nodes.NwTt.NwTt;
import nasctime.nodes.NwTt.GptpSideband;
import nasctime.nodes.DsTt.DsTt;
import simu5g.nodes.gNodeB;
import nasctime.nodes.DsTt.NRUeDsTt;
import simu5g.nodes.Upf;
import simu5g.world.radio.LteChannelControl;
import simu5g.common.binder.Binder;
import simu5g.common.carrierAggregation.CarrierAggregation;
import inet.common.scenario.ScenarioManager;
import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.tsn.TsnDevice;
import inet.node.tsn.TsnSwitch;
import ned.DatarateChannel;

import nasctime.nodes.TsnAf.TsnAf;
import nasctime.nodes.TsnAf.StaticBmca;

//
// Uplink counterpart to MultiEndpointNetwork.
//
// Traffic direction is reversed: tsnDeviceB is the talker, tsnDeviceA the
// listener. A single TSN device B sits behind a TSN switch that fans out to
// two DS-TT/UE access legs. The legs are active/standby, not load-shared:
// only leg `activeLeg` carries data and gPTP; the other is L2-attached but
// idle (no IP forwarding on its UE, not in the gPTP spanning tree).
//
// The TSN switch on the A side is gone -- tsnDeviceA attaches straight to
// the NW-TT.
//
network UplinkNetwork
{
    parameters:
        int numUes = default(2);
        // Which DS-TT/UE leg is active. The standby leg stays wired but
        // carries neither data nor gPTP. See omnetpp_uplink.ini.
        int activeLeg = default(0);
        @display("bgb=1600,700");

    types:
        channel Eth1G extends DatarateChannel
        {
            datarate = 1Gbps;
            delay = 0.1us;
        }
        channel Eth10G extends DatarateChannel
        {
            datarate = 10Gbps;
            delay = 0.1us;
        }

    submodules:
        channelControl: LteChannelControl {
            @display("p=50,25;is=s");
        }
        routingRecorder: RoutingTableRecorder {
            @display("p=50,75;is=s");
        }
        configurator: Ipv4NetworkConfigurator {
            @display("p=50,125;is=s");
            config = xmldoc("uplink_ip_config.xml");
        }
        binder: Binder {
            @display("p=50,175;is=s");
        }
        carrierAggregation: CarrierAggregation {
            @display("p=50,225;is=s");
        }
        // Runtime reconfiguration driver. Its script defaults to an empty
        // <script></script>, so the module is inert unless a config points
        // `*.scenarioManager.script` at an XML file. See omnetpp_uplink.ini.
        scenarioManager: ScenarioManager {
            @display("p=50,375;is=s");
        }

        // Listener side: TSN device A straight onto the NW-TT (no switch)
        tsnDeviceA: TsnDevice {
            @display("p=150,350");
        }
        nwTt: NwTt {
            @display("p=350,350");
            ueAddress = "ue[0]";
            localAddress = "nwTt";
        }
        upf: Upf {
            @display("p=550,350");
        }
        gnb: gNodeB {
            @display("p=750,350;is=vl");
        }

        // Two access legs: UE + DS-TT, active/standby
        //
        // No layout arrangement here ('c' as the 3rd arg of 'p'): these have a
        // mobility submodule, and MobilityBase::setInitialPosition rejects
        // auto-arranged coordinates outright. That leaves one literal position
        // for the whole vector, which would stack every ue[i] on the same spot
        // -- both on the canvas and in the radio geometry. The way out is to
        // let the mobility module own the position instead of reading it from
        // here: omnetpp_uplink.ini sets `initFromDisplayString = false` and
        // gives each leg its own initialX/initialY, which the mobility module
        // then writes back into this display string at t=0.
        //
        // The coordinate below is therefore only what the NED editor draws
        // before any ini is applied; keep it in step with ue[0] in the ini.
        ue[numUes]: NRUeDsTt {
            @display("p=950,250");
        }
        dsTt[numUes]: DsTt {
            @display("p=1120,250,c,200");
        }

        // Talker side: one TSN device behind a switch that fans out to
        // both DS-TTs
        tsnSwitchB: TsnSwitch {
            @display("p=1300,350");
        }
        tsnDeviceB: TsnDevice {
            @display("p=1470,350");
        }

        tsnAf: TsnAf {
            @display("p=50,275;is=s");
            cncConfig = xmldoc("cnc_config.xml");
        }
        staticBmca: StaticBmca {
            @display("p=50,325;is=s");
        }

        // gPTP sideband (NW-TT to the active leg's DS-TT)
        gptpSideband: GptpSideband {
            @display("p=740,150");
        }

    connections:
        // Listener side + 5G core
        tsnDeviceA.ethg++ <--> Eth1G <--> nwTt.tsnEthg;
        nwTt.filterGate <--> Eth10G <--> upf.dnPppg;
        upf.pppg++ <--> Eth10G <--> gnb.ppp;

        // Access legs
        for i=0..numUes-1 {
            ue[i].ethg <--> Eth1G <--> dsTt[i].ueEthg;
        }

        // Talker-side TSN island. Connection order fixes the switch port
        // numbering the .ini and the BMCA spanning tree rely on:
        //   eth0..eth(numUes-1) -> dsTt[0..numUes-1], eth(numUes) -> tsnDeviceB
        for i=0..numUes-1 {
            dsTt[i].tsnEthg <--> Eth1G <--> tsnSwitchB.ethg++;
        }
        tsnSwitchB.ethg++ <--> Eth1G <--> tsnDeviceB.ethg++;

        // gPTP sideband
        nwTt.gptpSidebandOut --> gptpSideband.nwttIn;
        gptpSideband.dsttOut --> dsTt[activeLeg].gptpSidebandIn;
}
