//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// NrNicUeDC — UE NIC with genuine NR-NR Dual Connectivity for FRER
//
// Extends NrNicUe with a second, fully independent NR leg (PHY/MAC/RLC/
// PDCP/SDAP) for FRER transport diversity across two distinct gNBs. Unlike
// Simu5G's native EN-DC (LTE anchor + NR secondary, built into NrNicUe's
// own inherited LteNicUeD2D base), this is NR+NR -- both legs are NrPhyUe
// instances, paired via a third HandoverController instance rather than
// the native LTE<->NR pairing.
//
// Design confirmed via direct reading of v1.5.0 source, not inferred:
//   - Binder::registerDcSecondary/getDcSecondaryNextHop -- ported from
//     v1.4.1-sdap-2, non-destructive w.r.t. servingNode_.
//   - HandoverController::isDcSecondary_ -- guards the three Binder
//     registration call sites so the secondary leg's attach/detach never
//     clobbers the primary's slot. beaconReceived()/triggerHandover()/
//     deleteOldBuffers() confirmed already generic, no changes needed.
//   - Rrc.ned: hasNrHandoverController2 gates the third HandoverController
//     instance -- MUST be declared inside Rrc itself (HandoverController
//     finds bearerManagement_ via getParentModule()), so this NIC can only
//     enable it via the rrc.hasNrHandoverController2 parameter, not inject
//     a submodule from outside.
//   - LtePhyUe.ned: handoverControllerModule is a plain NED string param
//     (default "^.rrc.handoverController"), confirmed via
//     grep -- nrPhy2.handoverControllerModule below overrides it to pair
//     with nrHandoverController2 instead. No C++ patch needed for this.
//   - BearerManagement.dcSecondaryDrbIds (set in the ini, not here) routes
//     DRB 4 (FRER replica) to nrRlcMux2/nrMac2/pdcpMux2.
//   - LtePhyEnb::handleAirFrame() / LtePhyBase::getReceiverGateIndex() --
//     gNB-side patches, not reflected in this file.
//
// STATUS: NED wiring complete and internally consistent as of this
// session. OPEN, NOT YET SOLVED: nothing here (or anywhere else in the
// design) forces nrPhy2/nrHandoverController2 to attach specifically to
// a UE's registered DC-secondary gNB rather than any available NR cell --
// see FRER_DC_design_state.md's "New gap" section. Do not trust
// dual-connectivity attach behavior until that's resolved.
//
package nasctime.nodes;

import simu5g.stack.NrNicUe;
import simu5g.stack.mac.ILteMac;
import simu5g.stack.phy.ILtePhy;
import simu5g.stack.phy.channelmodel.ILteChannelModel;
import simu5g.stack.phy.feedback.LteDlFeedbackGenerator;
import simu5g.stack.pdcp.UpperMux;
import simu5g.stack.rlc.RlcMux;
import simu5g.stack.sdap.INrSdap;
import nasctime.nodes.frer.NrDcMux;

module NrNicUeDC extends NrNicUe
{
    parameters:
        bool dualConnEnabled = default(false);
        string nrChannelModel2Type = default("NrChannelModel_3GPP38_901");

        nrPhy2.channelModelModule = "^.nrChannelModel2[0]";
        nrPhy2.feedbackGeneratorModule = "^.nrDlFbGen2";

        // FIX (was broken): the third HandoverController instance is
        // enabled via Rrc's own hasNrHandoverController2 flag, not by
        // trying to set rrc.nrHandoverController2.typename from outside
        // -- that submodule must already be declared inside Rrc.ned
        // itself (patched separately) for this to mean anything.
        rrc.hasNrHandoverController2 = dualConnEnabled;
        rrc.nrHandoverController2.isNr = true;
        rrc.nrHandoverController2.isDcSecondary = true;
        rrc.nrHandoverController2.macModule = "^.^.nrMac2";
        rrc.nrHandoverController2.feedbackGeneratorModule = "^.^.nrDlFbGen2";
        rrc.nrHandoverController2.otherHandoverControllerModule = "^.nrHandoverController";

        // Pairs nrPhy2 with nrHandoverController2 instead of the primary
        // nrHandoverController -- confirmed sufficient via
        // LtePhyUe.ned's handoverControllerModule param, no C++ change needed.
        nrPhy2.handoverControllerModule = "^.rrc.nrHandoverController2";

    gates:
        input nrRadioIn2 @directIn @loose;

    submodules:
        nrDcMux: NrDcMux if dualConnEnabled {
            @display("p=439,230");
        }
        sdap2: <default("NrSdap")> like INrSdap if dualConnEnabled {
            @display("p=440,155");
        }
        pdcpMux2: UpperMux if dualConnEnabled {
            isNR = true;
            @display("p=440,350");
        }
        nrRlcMux2: RlcMux if dualConnEnabled {
            @display("p=440,430");
        }
        nrMac2: <default("NrMacUe")> like ILteMac if dualConnEnabled {
            @display("p=440,510");
        }
        nrPhy2: <default("NrPhyUe")> like ILtePhy if dualConnEnabled {
            @display("p=440,600");
        }
        nrChannelModel2[numNrCarriers]: <nrChannelModel2Type> like ILteChannelModel if dualConnEnabled {
            @display("p=200,400");
        }
        nrDlFbGen2: LteDlFeedbackGenerator if dualConnEnabled {
            @display("p=200,300");
            phyModule = "^.nrPhy2";
        }

    connections:
        // Confirmed against NrDcMux's real gate declarations
        // (inout upper/primary/secondary) -- $i/$o referencing verified.
        ip2nic.stackOut --> { @reconnect; } --> nrDcMux.upper$i if dualConnEnabled && hasSdap;
        nrDcMux.upper$o --> { @reconnect; } --> ip2nic.stackIn if dualConnEnabled && hasSdap;

        nrDcMux.primary$o --> sdap.upperLayerIn if dualConnEnabled;
        nrDcMux.primary$i <-- sdap.upperLayerOut if dualConnEnabled;
        nrDcMux.secondary$o --> sdap2.upperLayerIn if dualConnEnabled;
        nrDcMux.secondary$i <-- sdap2.upperLayerOut if dualConnEnabled;

        sdap2.pdcpOut --> pdcpMux2.upperLayerIn if dualConnEnabled;
        pdcpMux2.upperLayerOut --> sdap2.pdcpIn if dualConnEnabled;

        nrRlcMux2.macOut --> nrMac2.upperLayerIn if dualConnEnabled;
        nrRlcMux2.macIn <-- nrMac2.upperLayerOut if dualConnEnabled;
        nrMac2.phyOut --> nrPhy2.upperGateIn if dualConnEnabled;
        nrMac2.phyIn <-- nrPhy2.upperGateOut if dualConnEnabled;
        nrRadioIn2 --> nrPhy2.radioIn if dualConnEnabled;
}
