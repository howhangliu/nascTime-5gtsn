//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//

import inet.common.INETDefs;
import inet.common.packet.chunk.Chunk;

namespace simu5g;

//
// Custom header carrying the NW-TT ingress timestamp through the 5GS.
// Models the 3GPP GTP-U PDU Session Container extension header
// (TS 29.281 §5.2.1) which carries residence time information.
//
class GptpResidenceHeader extends inet::FieldsChunk
{
    chunkLength = inet::B(8);
    simtime_t ingressTime;  // NW-TT ingress timestamp
}