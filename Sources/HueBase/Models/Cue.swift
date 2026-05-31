import Foundation

struct Cue: Codable, Identifiable {
    let id: UUID
    var number: Double          // allows 1, 1.5, 2, etc.
    var name: String
    var layerSnapshot: [Layer]  // captured state of layers at cue creation
    var fadeInTime: Double      // seconds
    var fadeOutTime: Double     // seconds (crossfade to next cue)
    var followTime: Double?     // auto-advance after N seconds; nil = manual
    var notes: String

    init(
        id: UUID = UUID(),
        number: Double,
        name: String = "",
        layerSnapshot: [Layer] = [],
        fadeInTime: Double = 1.0,
        fadeOutTime: Double = 1.0,
        followTime: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.layerSnapshot = layerSnapshot
        self.fadeInTime = fadeInTime
        self.fadeOutTime = fadeOutTime
        self.followTime = followTime
        self.notes = notes
    }
}
