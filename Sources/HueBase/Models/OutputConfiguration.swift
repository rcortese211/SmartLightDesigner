import Foundation

struct UniverseMapping: Codable, Identifiable, Hashable {
    let id: UUID
    var localUniverse: Int      // internal universe index (0-based)
    var outputUniverse: Int     // universe sent on the wire
}

struct ArtNetConfiguration: Codable {
    var enabled: Bool = false
    var targetIP: String = "255.255.255.255"   // broadcast
    var port: UInt16 = 6454
    var universeMappings: [UniverseMapping] = [
        UniverseMapping(id: UUID(), localUniverse: 0, outputUniverse: 0)
    ]
    var sendInterval: Double = 1.0 / 44.0     // ~44 fps
}

struct SACNConfiguration: Codable {
    var enabled: Bool = false
    var sourceName: String = "HueBase"
    var priority: UInt8 = 100
    var port: UInt16 = 5568
    var universeMappings: [UniverseMapping] = [
        UniverseMapping(id: UUID(), localUniverse: 0, outputUniverse: 1)
    ]
    var useMulticast: Bool = true
}

struct USBDMXConfiguration: Codable {
    var enabled: Bool = false
    var portPath: String = ""   // e.g. /dev/cu.usbserial-ENTTEC
    var universe: Int = 0       // which internal universe to output
    var refreshRate: Int = 44
}

struct OSCConfiguration: Codable {
    var enabled: Bool = true
    var listenPort: UInt16 = 8000
    var sendIP: String = "127.0.0.1"
    var sendPort: UInt16 = 8001
}

// MARK: - Philips Hue

struct HueLightMapping: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var lightId: String         // Hue bridge light ID (e.g. "1", "2")
    var universe: Int
    var startAddress: Int       // 1-based; expects R,G,B channels at offset 0,1,2
}

struct HueConfiguration: Codable {
    var enabled: Bool = false
    var bridgeIP: String = ""
    var username: String = ""   // Hue API key (obtained via link-button pairing)
    var lightMappings: [HueLightMapping] = []
    var updateRateHz: Double = 20   // Hue bridge accepts ~20 updates/sec per light
}

// MARK: - Timecode

enum TimecodeFrameRate: Double, Codable, CaseIterable, Identifiable {
    case fps24   = 24
    case fps25   = 25
    case fps2997 = 29.97
    case fps30   = 30

    var id: Double { rawValue }
    var label: String {
        switch self {
        case .fps24:   return "24 fps (Film)"
        case .fps25:   return "25 fps (EBU/PAL)"
        case .fps2997: return "29.97 fps (NTSC DF)"
        case .fps30:   return "30 fps (SMPTE)"
        }
    }
    /// Art-Net type field value
    var artNetType: UInt8 {
        switch self {
        case .fps24:   return 0
        case .fps25:   return 1
        case .fps2997: return 2
        case .fps30:   return 3
        }
    }
}

struct TimecodeConfiguration: Codable {
    // SMPTE / Art-Net Timecode receive
    var smpteEnabled: Bool = false
    var smpteSource: SMPTESource = .artNet
    var smpteFrameRate: TimecodeFrameRate = .fps25
    var artNetTimecodePort: UInt16 = 6454

    // Network Timecode Sync (HueBase custom protocol)
    var networkSyncEnabled: Bool = false
    var networkSyncMode: NetworkSyncMode = .slave
    var networkSyncPort: UInt16 = 5765
    var networkSyncBroadcast: String = "255.255.255.255"

    enum SMPTESource: String, Codable, CaseIterable {
        case artNet   = "Art-Net Timecode"
        case manual   = "Manual / Internal"
    }
    enum NetworkSyncMode: String, Codable, CaseIterable {
        case master = "Master (broadcast)"
        case slave  = "Slave (receive)"
    }
}
