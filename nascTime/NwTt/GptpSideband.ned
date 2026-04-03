//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//

package simu5g.nodes.nascTime.NwTt;

// Models the 5GS transit delay for gPTP sideband messages.
// In G3, this delay will be replaced by measured residence time.
simple GptpSideband
{
    parameters:
        @display("i=block/delay");
        @class(::GptpSideband);
        double sidebandDelay @unit(s) = default(2ms);  // models 5GS transit time

    gates:
        input nwttIn;   // from NW-TT
        output dsttOut;  // to DS-TT
        input dsttIn @loose;   // from DS-TT (for future bidirectional)
        output nwttOut @loose;  // to NW-TT (for future bidirectional)
}
