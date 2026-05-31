import Foundation

struct Show: Codable {
    var name: String = ""
    var fixtureProfiles: [FixtureProfile] = []
    var fixtures: [Fixture] = []
    var layers: [Layer] = []
    var cues: [Cue] = []
    var artNet: ArtNetConfiguration = ArtNetConfiguration()
    var sACN: SACNConfiguration = SACNConfiguration()
    var usbDMX: USBDMXConfiguration = USBDMXConfiguration()
    var osc: OSCConfiguration = OSCConfiguration()
    var hue: HueConfiguration = HueConfiguration()
    var timecode: TimecodeConfiguration = TimecodeConfiguration()
    var savedScripts: [SavedScript] = []
    var notes: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    func profile(for fixture: Fixture) -> FixtureProfile? {
        fixtureProfiles.first(where: { $0.id == fixture.profileId })
    }

    mutating func addCue(from layers: [Layer]) {
        let nextNumber = (cues.map(\.number).max() ?? 0) + 1
        let cue = Cue(number: nextNumber, name: "Cue \(Int(nextNumber))", layerSnapshot: layers)
        cues.append(cue)
    }
}

struct SavedScript: Codable, Identifiable {
    let id: UUID
    var name: String
    var source: String

    init(id: UUID = UUID(), name: String = "Script", source: String = "") {
        self.id = id
        self.name = name
        self.source = source
    }
}
