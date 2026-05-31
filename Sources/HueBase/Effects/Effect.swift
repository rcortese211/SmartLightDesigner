import Foundation

// Channel values keyed by offset within a fixture's channel block.
typealias FixtureChannels = [Int: UInt8]

enum ParameterType: Equatable {
    case double(min: Double, max: Double)
    case color
    case string
    case bool
    case select(options: [String])
}

struct EffectParameterDefinition {
    let key: String
    let name: String
    let type: ParameterType
    let defaultValue: ParameterValue
}

// Conform to this protocol to add a new effect.
// Audio / MIDI inputs can drive parameters by writing into the parameters dict
// before each render call — no changes to this protocol needed.
protocol Effect: Sendable {
    var id: String { get }
    var name: String { get }
    var parameterDefinitions: [EffectParameterDefinition] { get }

    func render(
        fixture: Fixture,
        profile: FixtureProfile,
        parameters: [String: ParameterValue],
        time: Double,
        speed: Double
    ) -> FixtureChannels
}

// Helpers shared across effects
extension Effect {
    func setRGB(
        _ result: inout FixtureChannels,
        profile: FixtureProfile,
        r: Double, g: Double, b: Double
    ) {
        for ch in profile.channels {
            switch ch.name.lowercased() {
            case "red",   "r": result[ch.offset] = UInt8(clamp(r) * 255)
            case "green", "g": result[ch.offset] = UInt8(clamp(g) * 255)
            case "blue",  "b": result[ch.offset] = UInt8(clamp(b) * 255)
            case "white", "w": result[ch.offset] = UInt8(clamp(min(r, g, b)) * 255)
            case "amber", "a": result[ch.offset] = UInt8(clamp((r + g) / 2 * 0.7) * 255)
            case "dimmer", "intensity", "master":
                result[ch.offset] = UInt8(clamp(max(r, g, b)) * 255)
            default: result[ch.offset] = result[ch.offset] ?? 0
            }
        }
    }

    private func clamp(_ v: Double) -> Double { max(0, min(1, v)) }
}

func hsvToRGB(h: Double, s: Double, v: Double) -> (r: Double, g: Double, b: Double) {
    let h6 = (h.truncatingRemainder(dividingBy: 1.0) * 6.0 + 6.0).truncatingRemainder(dividingBy: 6.0)
    let i = Int(h6)
    let f = h6 - Double(i)
    let p = v * (1 - s)
    let q = v * (1 - s * f)
    let t = v * (1 - s * (1 - f))
    switch i {
    case 0: return (v, t, p)
    case 1: return (q, v, p)
    case 2: return (p, v, t)
    case 3: return (p, q, v)
    case 4: return (t, p, v)
    default: return (v, p, q)
    }
}
