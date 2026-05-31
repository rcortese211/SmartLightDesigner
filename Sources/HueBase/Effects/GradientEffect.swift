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
        let cycle = parameters["cycle"]?.doubleValue ?? 1.0
        let width = parameters["width"]?.doubleValue ?? 1.0

        let offset = cycle > 0.5 ? (time * speed * 0.2).truncatingRemainder(dividingBy: 1.0) : 0.0
        let t = ((fixture.positionX + offset) * width).truncatingRemainder(dividingBy: 1.0)
        let smoothT = t * t * (3 - 2 * t)  // smoothstep

        let r = ar + (br - ar) * smoothT
        let g = ag + (bg - ag) * smoothT
        let b = ab + (bb - ab) * smoothT

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile, r: r, g: g, b: b)
        return result
    }
}
