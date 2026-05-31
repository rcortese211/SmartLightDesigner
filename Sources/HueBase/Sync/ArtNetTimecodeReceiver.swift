import Foundation
import Network

/// Listens on the Art-Net port for ArtTimeCode packets (OpCode 0x9700)
/// and feeds decoded SMPTE timecodes to the TimecodeEngine.
final class ArtNetTimecodeReceiver {
    private var listener: NWListener?
    private weak var engine: TimecodeEngine?
    private var lastReceivedAt: Date?
    private let timeoutInterval: TimeInterval = 2.0   // declare lost after 2s silence

    var port: UInt16 = 6454

    init(engine: TimecodeEngine) {
        self.engine = engine
    }

    func start() {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        listener = try? NWListener(using: params, on: nwPort)
        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global(qos: .utility))
            self?.receive(on: conn)
        }
        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        engine?.lostSMPTE()
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data {
                self?.handle(data)
            }
            if error == nil { self?.receive(on: connection) }
        }
    }

    private func handle(_ data: Data) {
        // Art-Net packet minimum: 10 bytes header + timecode data
        guard data.count >= 18 else { return }

        // Verify Art-Net ID "Art-Net\0"
        let artNetID: [UInt8] = [0x41,0x72,0x74,0x2D,0x4E,0x65,0x74,0x00]
        guard data.prefix(8).elementsEqual(artNetID) else { return }

        // OpCode at bytes 8-9 little-endian: ArtTimeCode = 0x9700 → [0x00, 0x97]
        guard data[8] == 0x00 && data[9] == 0x97 else { return }

        // ArtTimeCode payload (after 12-byte header):
        // byte 12: Filler1, 13: Filler2
        // byte 14: Frames (0-29)
        // byte 15: Seconds (0-59)
        // byte 16: Minutes (0-59)
        // byte 17: Hours (0-23)
        // byte 18: Type (0=Film/24, 1=EBU/25, 2=DF/29.97, 3=SMPTE/30)
        guard data.count >= 19 else { return }

        let tc = SMPTETimecode.fromArtNet(
            hours:   data[17],
            minutes: data[16],
            seconds: data[15],
            frames:  data[14],
            type:    data[18]
        )

        lastReceivedAt = Date()
        DispatchQueue.main.async { [weak self] in
            self?.engine?.receiveSMPTE(tc)
        }
    }

    // MARK: - Build an ArtTimeCode packet (for testing / re-broadcast)

    static func buildPacket(_ tc: SMPTETimecode) -> Data {
        var p = Data(count: 19)
        // ID
        [0x41,0x72,0x74,0x2D,0x4E,0x65,0x74,0x00].enumerated().forEach { p[$0] = $1 }
        // OpCode 0x9700 little-endian
        p[8] = 0x00; p[9] = 0x97
        // ProtVer 14
        p[10] = 0x00; p[11] = 0x0E
        // Filler
        p[12] = 0; p[13] = 0
        // TC
        p[14] = UInt8(tc.frames)
        p[15] = UInt8(tc.seconds)
        p[16] = UInt8(tc.minutes)
        p[17] = UInt8(tc.hours)
        p[18] = tc.frameRate.artNetType
        return p
    }
}
