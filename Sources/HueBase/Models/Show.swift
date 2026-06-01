import Foundation

struct NamedSpatialZone: Codable, Identifiable {
    let id: UUID
    var name: String
    var zone: SpatialZone

    init(id: UUID = UUID(), name: String, zone: SpatialZone) {
        self.id = id; self.name = name; self.zone = zone
    }
}

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
    var effectFolders: [EffectFolder] = []
    var globalColors: [GlobalColor] = []
    var savedScripts: [SavedScript] = []
    var timeline: Timeline = Timeline()
    var audio: AudioConfiguration = AudioConfiguration()
    var zoneLibrary: [NamedSpatialZone] = []
    var notes: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    func profile(for fixture: Fixture) -> FixtureProfile? {
        fixtureProfiles.first(where: { $0.id == fixture.profileId })
    }

    // Defensive decoder: every field uses decodeIfPresent so that show files created
    // before a field existed still open cleanly with sensible defaults.
    init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        name            = try c.decodeIfPresent(String.self,                forKey: .name)           ?? ""
        fixtureProfiles = try c.decodeIfPresent([FixtureProfile].self,      forKey: .fixtureProfiles) ?? []
        fixtures        = try c.decodeIfPresent([Fixture].self,             forKey: .fixtures)       ?? []
        layers          = try c.decodeIfPresent([Layer].self,               forKey: .layers)         ?? []
        cues            = try c.decodeIfPresent([Cue].self,                 forKey: .cues)           ?? []
        artNet          = try c.decodeIfPresent(ArtNetConfiguration.self,   forKey: .artNet)         ?? ArtNetConfiguration()
        sACN            = try c.decodeIfPresent(SACNConfiguration.self,     forKey: .sACN)           ?? SACNConfiguration()
        usbDMX          = try c.decodeIfPresent(USBDMXConfiguration.self,   forKey: .usbDMX)         ?? USBDMXConfiguration()
        osc             = try c.decodeIfPresent(OSCConfiguration.self,      forKey: .osc)            ?? OSCConfiguration()
        hue             = try c.decodeIfPresent(HueConfiguration.self,      forKey: .hue)            ?? HueConfiguration()
        timecode        = try c.decodeIfPresent(TimecodeConfiguration.self, forKey: .timecode)       ?? TimecodeConfiguration()
        effectFolders   = try c.decodeIfPresent([EffectFolder].self,        forKey: .effectFolders)  ?? []
        globalColors    = try c.decodeIfPresent([GlobalColor].self,         forKey: .globalColors)   ?? []
        savedScripts    = try c.decodeIfPresent([SavedScript].self,         forKey: .savedScripts)   ?? []
        timeline        = try c.decodeIfPresent(Timeline.self,              forKey: .timeline)       ?? Timeline()
        audio           = try c.decodeIfPresent(AudioConfiguration.self,    forKey: .audio)          ?? AudioConfiguration()
        zoneLibrary     = try c.decodeIfPresent([NamedSpatialZone].self,    forKey: .zoneLibrary)    ?? []
        notes           = try c.decodeIfPresent(String.self,                forKey: .notes)          ?? ""
        createdAt       = try c.decodeIfPresent(Date.self,                  forKey: .createdAt)      ?? Date()
        modifiedAt      = try c.decodeIfPresent(Date.self,                  forKey: .modifiedAt)     ?? Date()
    }

    mutating func addCue(from layers: [Layer]) {
        let nextNumber = (cues.map(\.number).max() ?? 0) + 1
        let cue = Cue(number: nextNumber, name: "Cue \(Int(nextNumber))", layerSnapshot: layers)
        cues.append(cue)
    }
}

struct GlobalColor: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var r: Double
    var g: Double
    var b: Double

    init(id: UUID = UUID(), name: String, r: Double, g: Double, b: Double) {
        self.id = id; self.name = name; self.r = r; self.g = g; self.b = b
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
