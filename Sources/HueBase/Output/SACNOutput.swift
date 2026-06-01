import Foundation
import Network

// E1.31 (sACN) output driver
final class SACNOutput: DMXOutputDriver {
    var isEnabled: Bool
    var config: SACNConfiguration
    // output universe → one connection per destination (multicast: 1; unicast: N)
    private var connections: [Int: [NWConnection]] = [:]
    private var sequence: UInt8 = 0

    // sACN source CID — fixed per session
    private let cid: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }

    init(config: SACNConfiguration) {
        self.config = config
        self.isEnabled = config.enabled
    }

    func start() {}
    func stop() {
        connections.values.flatMap { $0 }.forEach { $0.cancel() }
        connections.removeAll()
    }

    func send(universe: Int, values: [UInt8]) {
        guard isEnabled else { return }

        let outputUniverse = config.universeMappings
            .first(where: { $0.localUniverse == universe })?.outputUniverse ?? universe

        if connections[outputUniverse] == nil {
            connections[outputUniverse] = makeConnections(universe: outputUniverse)
        }
        guard let conns = connections[outputUniverse], !conns.isEmpty else { return }

        sequence = sequence &+ 1
        let packet = buildSACNPacket(universe: outputUniverse, sequence: sequence, values: values)
        for conn in conns {
            conn.send(content: packet, completion: .idempotent)
        }
    }

    // Builds one connection per destination. Multicast → one connection to 239.255.X.Y.
    // Unicast → one connection per entry in unicastDestinations; falls back to broadcast if empty.
    private func makeConnections(universe: Int) -> [NWConnection] {
        let port = NWEndpoint.Port(rawValue: config.port) ?? 5568
        func make(_ host: String) -> NWConnection {
            let c = NWConnection(to: .hostPort(host: NWEndpoint.Host(host), port: port), using: .udp)
            c.start(queue: .global(qos: .userInteractive))
            return c
        }
        if config.useMulticast {
            let hi = (universe >> 8) & 0xFF
            let lo = universe & 0xFF
            return [make("239.255.\(hi).\(lo)")]
        } else {
            let dests = config.unicastDestinations
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return dests.isEmpty ? [make("255.255.255.255")] : dests.map { make($0) }
        }
    }

    private func buildSACNPacket(universe: Int, sequence: UInt8, values: [UInt8]) -> Data {
        let dataLen = values.count
        let dmpLen     = 11 + dataLen   // 2 flags+len + 1 vec + 1 type + 2+2 addr + 2 propCount + 1 startCode + N data
        let framingLen = 88 + dataLen   // 2 + 4 + 64 + 1 + 2 + 1 + 1 + 2 (header=77) + dmpLen
        let rootLen    = 110 + dataLen  // 2 + 4 + 16 (header=22) + framingLen
        let totalLen   = 126 + dataLen  // 16 (preamble+postamble+ACN ID) + rootLen

        var p = Data(capacity: totalLen)

        // --- Root Layer ---
        p.append(contentsOf: [0x00, 0x10])  // Preamble size
        p.append(contentsOf: [0x00, 0x00])  // Postamble size
        // ACN packet identifier (12 bytes)
        p.append(contentsOf: [0x41,0x53,0x43,0x2D,0x45,0x31,0x2E,0x31,0x37,0x00,0x00,0x00])
        // Flags + length (root)
        let rootFlags = UInt16(0x7000) | UInt16(rootLen)
        p.append(UInt8(rootFlags >> 8)); p.append(UInt8(rootFlags & 0xFF))
        // Vector VECTOR_ROOT_E131_DATA = 0x00000004
        p.append(contentsOf: [0x00, 0x00, 0x00, 0x04])
        // CID (16 bytes)
        p.append(contentsOf: cid)

        // --- Framing Layer ---
        let framingFlags = UInt16(0x7000) | UInt16(framingLen)
        p.append(UInt8(framingFlags >> 8)); p.append(UInt8(framingFlags & 0xFF))
        // Vector VECTOR_E131_DATA_PACKET = 0x00000002
        p.append(contentsOf: [0x00, 0x00, 0x00, 0x02])
        // Source Name (64 bytes, null-padded)
        var sourceName = Array(config.sourceName.utf8.prefix(63))
        sourceName.append(contentsOf: Array(repeating: 0, count: 64 - sourceName.count))
        p.append(contentsOf: sourceName)
        // Priority
        p.append(config.priority)
        // Synchronization address
        p.append(contentsOf: [0x00, 0x00])
        // Sequence
        p.append(sequence)
        // Options
        p.append(0)
        // Universe
        p.append(UInt8((universe >> 8) & 0xFF)); p.append(UInt8(universe & 0xFF))

        // --- DMP Layer ---
        let dmpFlags = UInt16(0x7000) | UInt16(dmpLen)
        p.append(UInt8(dmpFlags >> 8)); p.append(UInt8(dmpFlags & 0xFF))
        // Vector VECTOR_DMP_SET_PROPERTY = 0x02
        p.append(0x02)
        // Address type & data type
        p.append(0xA1)
        // First property address
        p.append(contentsOf: [0x00, 0x00])
        // Address increment
        p.append(contentsOf: [0x00, 0x01])
        // Property count (start code + data)
        let propCount = UInt16(dataLen + 1)
        p.append(UInt8(propCount >> 8)); p.append(UInt8(propCount & 0xFF))
        // Start code 0x00 + DMX data
        p.append(0x00)
        p.append(contentsOf: values)

        return p
    }
}
