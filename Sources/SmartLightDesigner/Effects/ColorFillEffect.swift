import Foundation

struct ColorFillEffect: Effect {
    let id = "color_fill"
    let name = "Color Fill"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color", name: "Color", type: .color,
            defaultValue: .color(r: 1, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "brightness", name: "Brightness", type: .double(min: 0, max: 1),
            defaultValue: .double(1.0)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (r, g, b) = parameters["color"]?.colorValue ?? (1, 0, 0)
        let brightness = parameters["brightness"]?.doubleValue ?? 1.0
        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile, r: r * brightness, g: g * brightness, b: b * brightness)
        return result
    }
}
