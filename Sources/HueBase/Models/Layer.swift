import Foundation

enum DMXBlendMode: String, Codable, CaseIterable, Identifiable {
    // Basic
    case normal       = "Normal"
    case override     = "Override"
    // Darken group
    case darken       = "Darken"
    case multiply     = "Multiply"
    case colorBurn    = "Color Burn"
    case linearBurn   = "Linear Burn"
    // Lighten group
    case lighten      = "Lighten (HTP)"
    case screen       = "Screen"
    case colorDodge   = "Color Dodge"
    case linearDodge  = "Add"
    // Contrast group
    case overlay      = "Overlay"
    case softLight    = "Soft Light"
    case hardLight    = "Hard Light"
    case vividLight   = "Vivid Light"
    case linearLight  = "Linear Light"
    case pinLight     = "Pin Light"
    case hardMix      = "Hard Mix"
    // Inversion group
    case difference   = "Difference"
    case exclusion    = "Exclusion"
    // Component group
    case subtract     = "Subtract"
    case divide       = "Divide"
    case negativeMask = "Negative Mask"

    var id: String { rawValue }
}

// ParameterValue holds typed values for effect parameters.
// Audio/MIDI inputs can be patched in by adding new cases here.
enum ParameterValue: Hashable {
    case double(Double)
    case color(r: Double, g: Double, b: Double)
    case string(String)
    case bool(Bool)
    case colorList([(r: Double, g: Double, b: Double)])

    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }
    var colorValue: (r: Double, g: Double, b: Double)? {
        if case .color(let r, let g, let b) = self { return (r, g, b) }
        return nil
    }
    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
    var colorListValue: [(r: Double, g: Double, b: Double)]? {
        if case .colorList(let v) = self { return v }
        return nil
    }

    static func == (lhs: ParameterValue, rhs: ParameterValue) -> Bool {
        switch (lhs, rhs) {
        case (.double(let a), .double(let b)):       return a == b
        case (.color(let ar, let ag, let ab), .color(let br, let bg, let bb)):
            return ar == br && ag == bg && ab == bb
        case (.string(let a), .string(let b)):       return a == b
        case (.bool(let a), .bool(let b)):           return a == b
        case (.colorList(let a), .colorList(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.r == $1.r && $0.g == $1.g && $0.b == $1.b }
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .double(let v):         hasher.combine(0); hasher.combine(v)
        case .color(let r, let g, let b): hasher.combine(1); hasher.combine(r); hasher.combine(g); hasher.combine(b)
        case .string(let v):         hasher.combine(2); hasher.combine(v)
        case .bool(let v):           hasher.combine(3); hasher.combine(v)
        case .colorList(let v):      hasher.combine(4); v.forEach { hasher.combine($0.r); hasher.combine($0.g); hasher.combine($0.b) }
        }
    }
}

extension ParameterValue: Codable {
    private enum CodingKeys: String, CodingKey { case type, value, r, g, b, colors }
    private struct RGBEntry: Codable { var r, g, b: Double }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "double":    self = .double(try c.decode(Double.self, forKey: .value))
        case "color":     self = .color(r: try c.decode(Double.self, forKey: .r),
                                        g: try c.decode(Double.self, forKey: .g),
                                        b: try c.decode(Double.self, forKey: .b))
        case "string":    self = .string(try c.decode(String.self, forKey: .value))
        case "bool":      self = .bool(try c.decode(Bool.self, forKey: .value))
        case "colorList":
            let entries = try c.decode([RGBEntry].self, forKey: .colors)
            self = .colorList(entries.map { (r: $0.r, g: $0.g, b: $0.b) })
        default:          self = .double(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .double(let v):
            try c.encode("double", forKey: .type); try c.encode(v, forKey: .value)
        case .color(let r, let g, let b):
            try c.encode("color", forKey: .type)
            try c.encode(r, forKey: .r); try c.encode(g, forKey: .g); try c.encode(b, forKey: .b)
        case .string(let v):
            try c.encode("string", forKey: .type); try c.encode(v, forKey: .value)
        case .bool(let v):
            try c.encode("bool", forKey: .type); try c.encode(v, forKey: .value)
        case .colorList(let list):
            try c.encode("colorList", forKey: .type)
            try c.encode(list.map { RGBEntry(r: $0.r, g: $0.g, b: $0.b) }, forKey: .colors)
        }
    }
}

struct SpatialZone: Codable, Equatable {
    var x: Double = 0
    var y: Double = 0
    var width: Double = 1
    var height: Double = 1

    var isFullCanvas: Bool { x == 0 && y == 0 && width == 1 && height == 1 }
}

struct Layer: Codable, Identifiable {
    let id: UUID
    var name: String
    var effectId: String
    var isEnabled: Bool
    var opacity: Double         // 0-1
    var blendMode: DMXBlendMode
    var speed: Double           // 1.0 = normal
    var parameters: [String: ParameterValue]
    var fixtureIds: [UUID]      // empty = apply to all fixtures
    var zone: SpatialZone       // normalized 0-1 region; (0,0,1,1) = full canvas

    init(
        id: UUID = UUID(),
        name: String = "Layer",
        effectId: String = "color_fill",
        isEnabled: Bool = true,
        opacity: Double = 1.0,
        blendMode: DMXBlendMode = .normal,
        speed: Double = 1.0,
        parameters: [String: ParameterValue] = [:],
        fixtureIds: [UUID] = [],
        zone: SpatialZone = SpatialZone()
    ) {
        self.id = id
        self.name = name
        self.effectId = effectId
        self.isEnabled = isEnabled
        self.opacity = opacity
        self.blendMode = blendMode
        self.speed = speed
        self.parameters = parameters
        self.fixtureIds = fixtureIds
        self.zone = zone
    }
}
