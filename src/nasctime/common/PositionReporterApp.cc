#include "nasctime/common/PositionReporterApp.h"

#include <cstdint>

#include "inet/common/ModuleAccess.h"
#include "inet/common/Simsignals.h"
#include "inet/common/TimeTag_m.h"
#include "inet/common/packet/chunk/BytesChunk.h"
#include "inet/mobility/contract/IMobility.h"
#include "inet/networklayer/common/FragmentationTag_m.h"

using namespace inet;

namespace nasctime {

Define_Module(PositionReporterApp);

static void writeUint32(std::vector<uint8_t>& bytes, size_t offset, uint32_t value)
{
    bytes[offset] = (value >> 24) & 0xff;
    bytes[offset + 1] = (value >> 16) & 0xff;
    bytes[offset + 2] = (value >> 8) & 0xff;
    bytes[offset + 3] = value & 0xff;
}

void PositionReporterApp::sendPacket()
{
    auto *mobility = getModuleFromPar<IMobility>(par("mobilityModule"), this);
    const Coord position = mobility->getCurrentPosition();
    const Coord velocity = mobility->getCurrentVelocity();

    // Signed millimetre values are carried in two's-complement uint32 fields.
    std::vector<uint8_t> bytes(20);
    writeUint32(bytes, 0, static_cast<uint32_t>(numSent));
    writeUint32(bytes, 4, static_cast<uint32_t>(getParentModule()->getParentModule()->getIndex()));
    writeUint32(bytes, 8, static_cast<uint32_t>(static_cast<int32_t>(position.x * 1000)));
    writeUint32(bytes, 12, static_cast<uint32_t>(static_cast<int32_t>(position.y * 1000)));
    writeUint32(bytes, 16, static_cast<uint32_t>(static_cast<int32_t>(velocity.length() * 1000)));

    std::string name = std::string(packetName) + "-" + std::to_string(numSent);
    auto *packet = new Packet(name.c_str());
    if (dontFragment)
        packet->addTag<FragmentationReq>()->setDontFragment(true);
    const auto& payload = makeShared<BytesChunk>(bytes);
    payload->addTag<CreationTimeTag>()->setCreationTime(simTime());
    packet->insertAtBack(payload);

    emit(packetSentSignal, packet);
    socket.sendTo(packet, chooseDestAddr(), destPort);
    numSent++;
}

} // namespace nasctime
