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
