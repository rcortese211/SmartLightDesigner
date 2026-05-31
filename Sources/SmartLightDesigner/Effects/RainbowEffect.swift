import Foundation

struct RainbowEffect: Effect {
    let id = "rainbow"
    let name = "Rainbow"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "saturation", name: "Saturation", type: .double(min: 0, max: 1),
            defaultValue: .double(1.0)
        ),
        EffectParameterDefinition(
            key: "brightness", name: "Brightness", type: .double(min: 0, max: 1),
            defaultValue: .double(1.0)
        ),
        EffectParameterDefinition(
            key: "spread", name: "Spread", type: .double(min: 0.1, max: 4.0),
            defaultValue: .double(1.0)
        ),
        EffectParameterDefinition(
            key: "cycle_all", name: "Cycle All Together", type: .bool,
            defaultValue: .bool(false)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let saturation = parameters["saturation"]?.doubleValue ?? 1.0
        let brightness  = parameters["brightness"]?.doubleValue ?? 1.0
        let spread      = parameters["spread"]?.doubleValue ?? 1.0
        let cycleAll    = parameters["cycle_all"]?.boolValue ?? false

        let timeOffset = time * speed * 0.1
        let position = cycleAll ? 0.0 : fixture.positionX

        let hue = (position * spread + timeOffset).truncatingRemainder(dividingBy: 1.0)
        let (r, g, b) = hsvToRGB(h: hue, s: saturation, v: brightness)

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile, r: r, g: g, b: b)
        return result
    }
}
