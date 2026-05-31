import Foundation

struct StrobeEffect: Effect {
    let id = "strobe"
    let name = "Strobe"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color", name: "Color", type: .color,
            defaultValue: .color(r: 1, g: 1, b: 1)
        ),
        EffectParameterDefinition(
            key: "frequency", name: "Frequency (Hz)", type: .double(min: 0.5, max: 25),
            defaultValue: .double(4.0)
        ),
        EffectParameterDefinition(
            key: "duty_cycle", name: "Duty Cycle", type: .double(min: 0.01, max: 0.99),
            defaultValue: .double(0.5)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (r, g, b) = parameters["color"]?.colorValue ?? (1, 1, 1)
        let frequency = parameters["frequency"]?.doubleValue ?? 4.0
        let dutyCycle = parameters["duty_cycle"]?.doubleValue ?? 0.5

        let period = 1.0 / (frequency * speed)
        let phase = time.truncatingRemainder(dividingBy: period) / period
        let isOn = phase < dutyCycle

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: isOn ? r : 0, g: isOn ? g : 0, b: isOn ? b : 0)
        return result
    }
}
