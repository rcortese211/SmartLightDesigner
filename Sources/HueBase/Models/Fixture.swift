import Foundation

struct FixtureChannel: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var offset: Int
    var defaultValue: UInt8
}

struct FixtureProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var manufacturer: String
    var channels: [FixtureChannel]

    var channelCount: Int { channels.count }

    func channelOffset(named name: String) -> Int? {
        channels.first(where: { $0.name.lowercased() == name.lowercased() })?.offset
    }

    func channels(matching names: [String]) -> [FixtureChannel] {
        let lowered = names.map { $0.lowercased() }
        return channels.filter { lowered.contains($0.name.lowercased()) }
    }
}

struct Fixture: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var profileId: UUID
    var universe: Int
    var startAddress: Int   // 1-based DMX address
    var positionX: Double   // 0-1 normalized for visualizer
    var positionY: Double
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        profileId: UUID,
        universe: Int = 0,
        startAddress: Int = 1,
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.profileId = profileId
        self.universe = universe
        self.startAddress = startAddress
        self.positionX = positionX
        self.positionY = positionY
        self.notes = notes
    }
}
