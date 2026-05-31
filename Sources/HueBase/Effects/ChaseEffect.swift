import Foundation

struct ChaseEffect: Effect {
    let id = "chase"
    let name = "Chase"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_on",  name: "On Color",  type: .color,
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
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top",
                                    "Radial Out",  "Radial In"]),
            defaultValue: .string("Left→Right")
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (onR, onG, onB)   = parameters["color_on"]?.colorValue  ?? (1, 1, 1)
        let (offR, offG, offB) = parameters["color_off"]?.colorValue ?? (0, 0, 0)
        let density  = max(1.0, parameters["density"]?.doubleValue ?? 3.0)
        let dirStr   = parameters["direction"]?.stringValue ?? "Left→Right"

        // Map this fixture to a 0–1 position in the chase sequence
        let fixturePos: Double
        switch dirStr {
        case "Right→Left":  fixturePos = 1.0 - fixture.positionX
        case "Top→Bottom":  fixturePos = fixture.positionY
        case "Bottom→Top":  fixturePos = 1.0 - fixture.positionY
        case "Radial Out":
            let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
            fixturePos = min(1.0, sqrt(dx*dx + dy*dy) * 1.4142)
        case "Radial In":
            let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
            fixturePos = 1.0 - min(1.0, sqrt(dx*dx + dy*dy) * 1.4142)
        default:            fixturePos = fixture.positionX   // Left→Right
        }

        // Wave front position (0–1), advances with time
        let wavePos    = (time * speed * 0.25).truncatingRemainder(dividingBy: 1.0)
        let windowSize = 1.0 / density
        // Wrap-around distance from fixture to the wave front
        let diff = (fixturePos - wavePos + 1.0).truncatingRemainder(dividingBy: 1.0)
        let isOn = diff < windowSize

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: isOn ? onR : offR,
               g: isOn ? onG : offG,
               b: isOn ? onB : offB)
        return result
    }
}
