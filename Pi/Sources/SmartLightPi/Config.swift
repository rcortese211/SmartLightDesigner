import Foundation

enum PiMode: String, CaseIterable {
    case player, designer

    static func from(args: [String]) -> PiMode {
        for arg in args {
            if arg == "--designer" { return .designer }
            if arg == "--player"   { return .player }
        }
        // Default: check saved preference
        let saved = UserDefaults.standard.string(forKey: "piMode") ?? "player"
        return PiMode(rawValue: saved) ?? .player
    }
}

struct PiConfig {
    var mode: PiMode
    var httpPort: Int
    var artNetEnabled: Bool
    var artNetUniverse: Int
    var artNetIp: String
    var sacnEnabled: Bool
    var sacnUniverse: Int

    static func load() -> PiConfig {
        let d = UserDefaults.standard
        return PiConfig(
            mode:          PiMode(rawValue: d.string(forKey: "piMode") ?? "player") ?? .player,
            httpPort:      d.integer(forKey: "httpPort") != 0 ? d.integer(forKey: "httpPort") : 8080,
            artNetEnabled: d.bool(forKey: "artNetEnabled"),
            artNetUniverse: d.integer(forKey: "artNetUniverse") != 0 ? d.integer(forKey: "artNetUniverse") : 1,
            artNetIp:      d.string(forKey: "artNetIp") ?? "255.255.255.255",
            sacnEnabled:   d.bool(forKey: "sacnEnabled"),
            sacnUniverse:  d.integer(forKey: "sacnUniverse") != 0 ? d.integer(forKey: "sacnUniverse") : 1
        )
    }

    func save() {
        let d = UserDefaults.standard
        d.set(mode.rawValue, forKey: "piMode")
        d.set(httpPort,      forKey: "httpPort")
        d.set(artNetEnabled, forKey: "artNetEnabled")
        d.set(artNetUniverse, forKey: "artNetUniverse")
        d.set(artNetIp,      forKey: "artNetIp")
        d.set(sacnEnabled,   forKey: "sacnEnabled")
        d.set(sacnUniverse,  forKey: "sacnUniverse")
    }
}
