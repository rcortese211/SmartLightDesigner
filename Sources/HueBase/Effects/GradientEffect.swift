import Foundation

struct GradientEffect: Effect {
    let id = "gradient"
    let name = "Gradient"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_a", name: "Color A", type: .color,
            defaultValue: .color(r: 1, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "color_b", name: "Color B", type: .color,
            defaultValue: .color(r: 0, g: 0, b: 1)
        ),
        EffectParameterDefinition(
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top",
                                    "Diagonal↘",  "Diagonal↙"]),
            defaultValue: .string("Left→Right")
        ),
        EffectParameterDefinition(
            key: "cycle", name: "Cycle (0=static, 1=moving)", type: .double(min: 0, max: 1),
            defaultValue: .double(1.0)
        ),
        EffectParameterDefinition(
            key: "width", name: "Width", type: .double(min: 0.1, max: 4.0),
            defaultValue: .double(1.0)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (ar, ag, ab) = parameters["color_a"]?.colorValue ?? (1, 0, 0)
        let (br, bg, bb) = parameters["color_b"]?.colorValue ?? (0, 0, 1)
        let dirStr = parameters["direction"]?.stringValue ?? "Left→Right"
        let cycle  = parameters["cycle"]?.doubleValue ?? 1.0
        let width  = parameters["width"]?.doubleValue ?? 1.0

        // Spatial position along the chosen axis (0–1)
        let axisPos: Double
        switch dirStr {
        case "Right→Left":  axisPos = 1.0 - fixture.positionX
        case "Top→Bottom":  axisPos = fixture.positionY
        case "Bottom→Top":  axisPos = 1.0 - fixture.positionY
        case "Diagonal↘":   axisPos = (fixture.positionX + fixture.positionY) / 2.0
        case "Diagonal↙":   axisPos = ((1.0 - fixture.positionX) + fixture.positionY) / 2.0
        default:            axisPos = fixture.positionX    // Left→Right
        }

        let offset = cycle > 0.5 ? (time * speed * 0.2).truncatingRemainder(dividingBy: 1.0) : 0.0
        let t      = ((axisPos + offset) * width).truncatingRemainder(dividingBy: 1.0)
        let smoothT = t * t * (3 - 2 * t)  // smoothstep

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: ar + (br - ar) * smoothT,
               g: ag + (bg - ag) * smoothT,
               b: ab + (bb - ab) * smoothT)
        return result
    }
}
