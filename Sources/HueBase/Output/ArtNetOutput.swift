import Foundation
import Network

final class ArtNetOutput: DMXOutputDriver {
    var isEnabled: Bool
    var config: ArtNetConfiguration
    private var connection: NWConnection?
    private var sequence: UInt8 = 0

    // Static bytes shared by every ArtDmx packet: "Art-Net\0" + OpCode 0x0050 + protocol version 14
    private static let packetHeader: [UInt8] = [
        0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00,
        0x00, 0x50,
        0x00, 0x0E,
    ]

    init(config: ArtNetConfiguration) {
        self.config = config
        self.isEnabled = config.enabled
    }

    func start() {
        let host = NWEndpoint.Host(config.targetIP)
        let port = NWEndpoint.Port(rawValue: config.port) ?? 6454
        connection = NWConnection(host: host, port: port, using: .udp)
        connection?.start(queue: .global(qos: .userInteractive))
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    func send(universe: Int, values: [UInt8]) {
        guard isEnabled, let conn = connection else { return }

        let outputUniverse = config.universeMappings
            .first(where: { $0.localUniverse == universe })?.outputUniverse ?? universe

        sequence = sequence &+ 1
        let packet = buildArtDMXPacket(universe: outputUniverse, sequence: sequence, values: values)
        conn.send(content: packet, completion: .idempotent)
    }

    private func buildArtDMXPacket(universe: Int, sequence: UInt8, values: [UInt8]) -> Data {
        var p = Data(capacity: 18 + values.count)
        p.append(contentsOf: Self.packetHeader)
        // Sequence
        p.append(sequence)
        // Physical
        p.append(0)
        // Universe 15-bit, little-endian
        p.append(UInt8(universe & 0x00FF))
        p.append(UInt8((universe >> 8) & 0x7F))
        // Length, big-endian
        let len = values.count
        p.append(UInt8((len >> 8) & 0xFF))
        p.append(UInt8(len & 0xFF))
        // DMX data
        p.append(contentsOf: values)
        return p
    }
}
