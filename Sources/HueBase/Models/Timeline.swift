import Foundation
import UniformTypeIdentifiers

// MARK: - Timeline data models

struct TimelineClip: Codable, Identifiable {
    var id: UUID = UUID()
    var startTime: Double           // seconds from timeline start
    var duration: Double            // seconds
    var layers: [Layer]             // layer snapshot
    var label: String
    var colorHue: Double            // 0–1, for UI color-coding
    var fadeInDuration: Double      // crossfade-in seconds (set automatically from overlap)
    var fadeOutDuration: Double     // crossfade-out seconds

    init(
        id: UUID = UUID(),
        startTime: Double,
        duration: Double = 8.0,
        layers: [Layer] = [],
        label: String = "Clip",
        colorHue: Double = 0.72,
        fadeInDuration: Double = 0,
        fadeOutDuration: Double = 0
    ) {
        self.id = id; self.startTime = startTime; self.duration = duration
        self.layers = layers; self.label = label; self.colorHue = colorHue
        self.fadeInDuration = fadeInDuration; self.fadeOutDuration = fadeOutDuration
    }

    var endTime: Double { startTime + duration }
}

struct TimelineMarker: Codable, Identifiable {
    var id: UUID = UUID()
    var time: Double        // seconds from timeline start
    var label: String
    var colorHue: Double = 0.58
}

struct TimelineTrack: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var clips: [TimelineClip]
    var isMuted: Bool = false
    var opacity: Double = 1.0

    init(id: UUID = UUID(), name: String = "Track", clips: [TimelineClip] = []) {
        self.id = id; self.name = name; self.clips = clips
    }
}

struct AudioClip: Codable {
    var startTime: Double = 0
    var fileDuration: Double = 0    // 0 = unknown until loaded
    var volume: Double = 1.0
    var fileName: String = ""
    var fileBookmark: Data? = nil   // security-scoped bookmark
}

struct Timeline: Codable {
    var tracks: [TimelineTrack] = []
    var audioClip: AudioClip? = nil
    var loop: Bool = false
    var bpm: Double = 120.0
    var markers: [TimelineMarker] = []

    // Defensive decoder: any field absent from older files falls back to its default.
    init(from decoder: Decoder) throws {
        let c     = try decoder.container(keyedBy: CodingKeys.self)
        tracks    = try c.decodeIfPresent([TimelineTrack].self,   forKey: .tracks)    ?? []
        audioClip = try c.decodeIfPresent(AudioClip.self,         forKey: .audioClip)
        loop      = try c.decodeIfPresent(Bool.self,              forKey: .loop)      ?? false
        bpm       = try c.decodeIfPresent(Double.self,            forKey: .bpm)       ?? 120.0
        markers   = try c.decodeIfPresent([TimelineMarker].self,  forKey: .markers)   ?? []
    }
}

// MARK: - Palette → Timeline drag-and-drop

struct PaletteTransfer: Codable, Transferable {
    var paletteID: UUID
    var paletteName: String
    var layers: [Layer]

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .paletteTransfer)
    }
}

extension UTType {
    static let paletteTransfer = UTType(exportedAs: "com.huebase.palette-transfer")
}
