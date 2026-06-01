import Foundation

// Minimal show engine for the Pi — receives show JSON from Mac clients,
// drives Art-Net / sACN output, tracks status for the player UI.

actor ShowEngine {
    private(set) var showData: Data = Data()
    private(set) var outputEnabled = false
    private(set) var isPlaying = false
    private(set) var timelinePosition: Double = 0
    private(set) var activeCueName: String? = nil
    private(set) var timecodeSource = "internal"
    private let startTime = Date()

    private var dmxOutputTask: Task<Void, Never>? = nil
    private var artNetSocket: Int32 = -1
    private var config: PiConfig

    init(config: PiConfig) {
        self.config = config
    }

    // MARK: - Show state

    func applyShowData(_ data: Data) {
        showData = data
        // Future: decode and feed to rendering pipeline
    }

    func currentStatus() -> PiStatusPayload {
        PiStatusPayload(
            fps: 44,
            outputEnabled: outputEnabled,
            timelinePosition: timelinePosition,
            isPlaying: isPlaying,
            timecodeSource: timecodeSource,
            activeCueName: activeCueName,
            uptime: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Output control

    func enableOutput() {
        guard !outputEnabled else { return }
        outputEnabled = true
        startDMXLoop()
    }

    func disableOutput() {
        outputEnabled = false
        dmxOutputTask?.cancel()
        dmxOutputTask = nil
    }

    func handleCommand(_ cmd: CommandPayload) {
        switch cmd.cmd {
        case "output.on":        enableOutput()
        case "output.off":       disableOutput()
        case "tl.play":          isPlaying = true
        case "tl.pause":         isPlaying = false
        case "tl.stop":          isPlaying = false; timelinePosition = 0
        case "tc.source":        timecodeSource = cmd.arg ?? "internal"
        default: break
        }
    }

    // MARK: - DMX rendering loop

    private func startDMXLoop() {
        dmxOutputTask?.cancel()
        dmxOutputTask = Task {
            while outputEnabled && !Task.isCancelled {
                renderAndSend()
                try? await Task.sleep(nanoseconds: 22_727_272)  // ~44 fps
            }
        }
    }

    private func renderAndSend() {
        // Decode show and run effect stack
        // For now send a zero universe as placeholder
        guard config.artNetEnabled else { return }
        sendArtNet(universe: config.artNetUniverse, dmx: [UInt8](repeating: 0, count: 512))
    }

    // MARK: - Art-Net output (UDP)

    private func sendArtNet(universe: Int, dmx: [UInt8]) {
        // Art-Net DMX packet format
        var packet = [UInt8](repeating: 0, count: 18 + 512)
        let header: [UInt8] = [0x41,0x72,0x74,0x2D,0x4E,0x65,0x74,0x00] // "Art-Net\0"
        packet[0..<8] = ArraySlice(header)
        packet[8]  = 0x00  // OpCode low (OpDmx = 0x5000)
        packet[9]  = 0x50  // OpCode high
        packet[10] = 0x00  // Protocol version high
        packet[11] = 14    // Protocol version low
        packet[12] = 0     // Sequence
        packet[13] = 0     // Physical
        packet[14] = UInt8(universe & 0xFF)
        packet[15] = UInt8((universe >> 8) & 0xFF)
        packet[16] = 0x02  // Length high (512 = 0x0200)
        packet[17] = 0x00  // Length low
        packet[18..<(18+min(dmx.count, 512))] = ArraySlice(dmx.prefix(512))
        sendUDP(packet, to: config.artNetIp, port: 6454)
    }

    private func sendUDP(_ bytes: [UInt8], to host: String, port: UInt16) {
        // POSIX UDP send
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return }
        defer { close(sock) }
        var broadcast: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)
        _ = bytes.withUnsafeBytes { buf in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, buf.baseAddress, bytes.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
