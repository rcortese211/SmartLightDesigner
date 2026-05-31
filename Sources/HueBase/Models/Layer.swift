import Foundation

enum BlendMode: String, Codable, CaseIterable, Identifiable {
    case normal    = "Normal"
    case add       = "Add"
    case subtract  = "Subtract"
    case multiply  = "Multiply"
    case screen    = "Screen"
    case override  = "Override"

    var id: String { rawValue }
}

// ParameterValue holds typed values for effect parameters.
// Audio/MIDI inputs can be patched in by adding new cases here.
enum ParameterValue: Hashable {
    case double(Double)
    case color(r: Double, g: Double, b: Double)
    case string(String)
    case bool(Bool)

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
}

extension ParameterValue: Codable {
    private enum CodingKeys: String, CodingKey { case type, value, r, g, b }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "double": self = .double(try c.decode(Double.self, forKey: .value))
        case "color":  self = .color(r: try c.decode(Double.self, forKey: .r),
                                     g: try c.decode(Double.self, forKey: .g),
                                     b: try c.decode(Double.self, forKey: .b))
        case "string": self = .string(try c.decode(String.self, forKey: .value))
        case "bool":   self = .bool(try c.decode(Bool.self, forKey: .value))
        default:       self = .double(0)
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
        }
    }
}

struct Layer: Codable, Identifiable {
    let id: UUID
    var name: String
    var effectId: String
    var isEnabled: Bool
    var opacity: Double         // 0-1
    var blendMode: BlendMode
    var speed: Double           // 1.0 = normal
    var parameters: [String: ParameterValue]
    var fixtureIds: [UUID]      // empty = apply to all fixtures

    init(
        id: UUID = UUID(),
        name: String = "Layer",
        effectId: String = "color_fill",
        isEnabled: Bool = true,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        speed: Double = 1.0,
        parameters: [String: ParameterValue] = [:],
        fixtureIds: [UUID] = []
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
    }
}
