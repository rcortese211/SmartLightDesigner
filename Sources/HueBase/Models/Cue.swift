import Foundation

struct CuePaletteRef: Codable, Equatable {
    var folderID: UUID
    var folderName: String
    var paletteID: UUID
    var paletteName: String
}

struct Cue: Codable, Identifiable {
    let id: UUID
    var number: Double          // allows 1, 1.5, 2, etc.
    var name: String
    var layerSnapshot: [Layer]  // captured state of layers at cue creation
    var fadeInTime: Double      // seconds
    var fadeOutTime: Double     // seconds (crossfade to next cue)
    var followTime: Double?     // auto-advance after N seconds; nil = manual
    var notes: String
    var timecodeTime: Double? = nil   // seconds into show at which this cue auto-fires; nil = manual only
    var paletteRef: CuePaletteRef? = nil  // optional palette to recall when cue fires

    init(
        id: UUID = UUID(),
        number: Double,
        name: String = "",
        layerSnapshot: [Layer] = [],
        fadeInTime: Double = 1.0,
        fadeOutTime: Double = 1.0,
        followTime: Double? = nil,
        notes: String = "",
        timecodeTime: Double? = nil,
        paletteRef: CuePaletteRef? = nil
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.layerSnapshot = layerSnapshot
        self.fadeInTime = fadeInTime
        self.fadeOutTime = fadeOutTime
        self.followTime = followTime
        self.notes = notes
        self.timecodeTime = timecodeTime
        self.paletteRef = paletteRef
    }
}
