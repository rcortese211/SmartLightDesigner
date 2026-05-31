import Foundation

// Interference of multiple sine waves in X and Y — produces organic, lava-lamp patterns.
struct PlasmaEffect: Effect {
    let id = "plasma"
    let name = "Plasma"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_a", name: "Color A", type: .color,
            defaultValue: .color(r: 0, g: 0.2, b: 1)
        ),
        EffectParameterDefinition(
            key: "color_b", name: "Color B", type: .color,
            defaultValue: .color(r: 1, g: 0, b: 0.5)
        ),
        EffectParameterDefinition(
            key: "scale", name: "Scale", type: .double(min: 0.5, max: 6),
            defaultValue: .double(2.0)
        ),
        EffectParameterDefinition(
            key: "complexity", name: "Complexity", type: .double(min: 1, max: 4),
            defaultValue: .double(3.0)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (ar, ag, ab) = parameters["color_a"]?.colorValue ?? (0, 0.2, 1)
        let (br, bg, bb) = parameters["color_b"]?.colorValue ?? (1, 0, 0.5)
        let scale      = parameters["scale"]?.doubleValue ?? 2.0
        let complexity = parameters["complexity"]?.doubleValue ?? 3.0

        let x = fixture.positionX
        let y = fixture.positionY
        let t = time * speed * 0.15

        // Sum of sine waves at different frequencies and angles
        var v = sin(x * scale * .pi + t)
        if complexity >= 2 { v += sin(y * scale * .pi + t * 0.9) }
        if complexity >= 3 { v += sin((x + y) * scale * .pi * 0.7 + t * 1.3) }
        if complexity >= 4 { v += sin(sqrt(max(0.001, (x - 0.5)*(x - 0.5) + (y - 0.5)*(y - 0.5))) * scale * 2 * .pi - t * 0.7) }

        let terms = min(4, max(1, Int(complexity)))
        let blend = (v / Double(terms) + 1) / 2   // normalise to 0–1

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: ar + (br - ar) * blend,
               g: ag + (bg - ag) * blend,
               b: ab + (bb - ab) * blend)
        return result
    }
}
