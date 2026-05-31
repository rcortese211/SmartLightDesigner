import Foundation

struct ChaseEffect: Effect {
    let id = "chase"
    let name = "Chase"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_on", name: "On Color", type: .color,
            defaultValue: .color(r: 1, g: 1, b: 1)
        ),
        EffectParameterDefinition(
            key: "color_off", name: "Off Color", type: .color,
            defaultValue: .color(r: 0, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "density", name: "Density (1/N lit)", type: .double(min: 1, max: 16),
            defaultValue: .double(3.0)
        ),
        EffectParameterDefinition(
            key: "direction", name: "Direction (0=fwd, 1=rev)", type: .double(min: 0, max: 1),
            defaultValue: .double(0.0)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (onR, onG, onB) = parameters["color_on"]?.colorValue ?? (1, 1, 1)
        let (offR, offG, offB) = parameters["color_off"]?.colorValue ?? (0, 0, 0)
        let density = parameters["density"]?.doubleValue ?? 3.0
        let direction = (parameters["direction"]?.doubleValue ?? 0.0) > 0.5 ? -1.0 : 1.0

        let phase = (time * speed * direction).truncatingRemainder(dividingBy: density)
        let idx = Int(fixture.positionX * 100) % Int(max(1, density))
        let phaseInt = Int(abs(phase))
        let isOn = (idx + phaseInt) % Int(max(1, density)) == 0

        var result: FixtureChannels = [:]
        if isOn {
            setRGB(&result, profile: profile, r: onR, g: onG, b: onB)
        } else {
            setRGB(&result, profile: profile, r: offR, g: offG, b: offB)
        }
        return result
    }
}
