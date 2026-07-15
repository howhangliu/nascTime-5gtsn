//
//                  nascTime
//
// Authors: Mohamed Seliem (University College Cork)
//
// FrerSequenceHeader.msg — IEEE 802.1CB R-TAG simulation equivalent
//
// Lightweight 4-byte header carrying a stream identifier and a per-stream
// sequence number.  Functionally equivalent to the 802.1CB R-TAG
// (EtherType 0xF1C1) but encoded as an INET FieldsChunk so that it can
// be inserted at the back of any Packet and survive GTP-U tunnel transit.
//
// Inserted by FrerReplicator (NW-TT side), stripped by FrerRecovery
// (DS-TT side).
//

cplusplus {{
#include "inet/common/Units.h"
using namespace inet;
}}

import inet.common.INETDefs;
import inet.common.packet.chunk.Chunk;

namespace simu5g;

class FrerSequenceHeader extends inet::FieldsChunk
{
    chunkLength = B(4);
    uint16_t streamId = 0;         // identifies the compound stream (== primary DSCP)
    uint16_t sequenceNumber = 0;   // 16-bit wrapping counter per stream
}
