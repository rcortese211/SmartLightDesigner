import Foundation

// A Palette stores a named stack of effect layers as a preset.
// Recalling a palette copies its layers into the live engine stack.
struct EffectPalette: Codable, Identifiable {
    let id: UUID
    var name: String
    var layers: [Layer]     // ordered stack — bottom layer first
    var notes: String

    init(id: UUID = UUID(), name: String = "Palette", layers: [Layer] = [], notes: String = "") {
        self.id = id
        self.name = name
        self.layers = layers
        self.notes = notes
    }
}

// A Folder groups related palettes.
struct EffectFolder: Codable, Identifiable {
    let id: UUID
    var name: String
    var palettes: [EffectPalette]

    init(id: UUID = UUID(), name: String = "Folder", palettes: [EffectPalette] = []) {
        self.id = id
        self.name = name
        self.palettes = palettes
    }
}
