import Foundation

// Smoothly interpolates between two colors over time; optional spatial phase offset
// lets different fixtures be at different points in the cycle simultaneously.
struct ColorMorphEffect: Effect {
    let id = "color_morph"
    let name = "Color Morph"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_a", name: "Color A", type: .color,
            defaultValue: .color(r: 1, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "color_b", name: "Color B", type: .color,
            defaultValue: .color(r: 0, g: 0.4, b: 1)
        ),
        EffectParameterDefinition(
            key: "spatial_offset", name: "Spatial Offset", type: .double(min: 0, max: 2),
            defaultValue: .double(0.0)
        ),
        EffectParameterDefinition(
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top"]),
            defaultValue: .string("Left→Right")
        ),
        EffectParameterDefinition(
            key: "easing", name: "Easing",
            type: .select(options: ["Sine", "Linear", "Smooth"]),
            defaultValue: .string("Sine")
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (ar, ag, ab)  = parameters["color_a"]?.colorValue ?? (1, 0, 0)
        let (br, bg, bb)  = parameters["color_b"]?.colorValue ?? (0, 0.4, 1)
        let spatialOffset = parameters["spatial_offset"]?.doubleValue ?? 0.0
        let dirStr        = parameters["direction"]?.stringValue ?? "Left→Right"
        let easing        = parameters["easing"]?.stringValue ?? "Sine"

        let axisPos: Double
        switch dirStr {
        case "Right→Left":  axisPos = 1 - fixture.positionX
        case "Top→Bottom":  axisPos = fixture.positionY
        case "Bottom→Top":  axisPos = 1 - fixture.positionY
        default:            axisPos = fixture.positionX
        }

        let phase = time * speed * 0.2 + axisPos * spatialOffset
        let raw: Double
        switch easing {
        case "Linear":
            let p = phase.truncatingRemainder(dividingBy: 2.0)
            let pp = p < 0 ? p + 2 : p
            raw = pp < 1 ? pp : 2 - pp   // triangle
        case "Smooth":
            let p = (sin(phase * .pi) + 1) / 2
            raw = p * p * (3 - 2 * p)    // smoothstep of sine
        default: // Sine
            raw = (sin(phase * 2 * .pi) + 1) / 2
        }

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: ar + (br - ar) * raw,
               g: ag + (bg - ag) * raw,
               b: ab + (bb - ab) * raw)
        return result
    }
}
