import Foundation
import Network

/// HueBase Network Timecode Sync — a lightweight UDP protocol that lets multiple
/// HueBase instances (or any listener) stay frame-locked over a LAN.
///
/// Packet format (12 bytes total):
///   Bytes 0-3:  Magic "HBTC"
///   Bytes 4-11: SMPTETimecode.toNetworkPacket() → [HH, MM, SS, FF, rate, flags, 0, 0]
final class NetworkTimecodeSync {
    private static let magic: [UInt8] = [0x48, 0x42, 0x54, 0x43] // "HBTC"
    private static let packetSize = 12

    private var listener: NWListener?
    private var broadcastConnection: NWConnection?
    private var broadcastTimer: Timer?

    weak var engine: TimecodeEngine?
    var config: TimecodeConfiguration

    init(engine: TimecodeEngine, config: TimecodeConfiguration) {
        self.engine = engine
        self.config = config
    }

    func start() {
        switch config.networkSyncMode {
        case .master: startMaster()
        case .slave:  startSlave()
        }
    }

    func stop() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        broadcastConnection?.cancel()
        broadcastConnection = nil
        listener?.cancel()
        listener = nil
    }

    func updateConfig(_ newConfig: TimecodeConfiguration) {
        stop()
        config = newConfig
        if newConfig.networkSyncEnabled { start() }
    }

    // MARK: - Master

    private func startMaster() {
        let host = NWEndpoint.Host(config.networkSyncBroadcast)
        guard let port = NWEndpoint.Port(rawValue: config.networkSyncPort) else { return }
        broadcastConnection = NWConnection(host: host,
                                           endpoint: .hostPort(host: host, port: port),
                                           using: .udp)
        broadcastConnection?.start(queue: .global(qos: .utility))

        let fps = engine?.frameRate.rawValue ?? 25.0
        broadcastTimer = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            self?.broadcastCurrentTC()
        }
        RunLoop.main.add(broadcastTimer!, forMode: .common)
    }

    private func broadcastCurrentTC() {
        guard let tc = engine?.current else { return }
        let payload = Self.magic + tc.toNetworkPacket()
        broadcastConnection?.send(content: Data(payload), completion: .idempotent)
    }

    // MARK: - Slave

    private func startSlave() {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        guard let port = NWEndpoint.Port(rawValue: config.networkSyncPort) else { return }
        listener = try? NWListener(using: params, on: port)
        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global(qos: .utility))
            self?.receive(on: conn)
        }
        listener?.start(queue: .global(qos: .utility))
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data { self?.handle(data) }
            if error == nil { self?.receive(on: connection) }
        }
    }

    private func handle(_ data: Data) {
        guard data.count == Self.packetSize else { return }
        let bytes = [UInt8](data)
        guard bytes.prefix(4).elementsEqual(Self.magic) else { return }
        let tcBytes = Array(bytes[4...])
        guard let tc = SMPTETimecode.fromNetworkPacket(tcBytes) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.engine?.receiveNetworkTimecode(tc)
        }
    }
}
