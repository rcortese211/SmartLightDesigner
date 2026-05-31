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
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top",
                                    "Radial Out",  "Radial In"]),
            defaultValue: .string("Left→Right")
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
        let dirStr      = parameters["direction"]?.stringValue ?? "Left→Right"

        let timeOffset = time * speed * 0.1

        let axisPos: Double
        if cycleAll {
            axisPos = 0.0
        } else {
            switch dirStr {
            case "Right→Left":  axisPos = 1.0 - fixture.positionX
            case "Top→Bottom":  axisPos = fixture.positionY
            case "Bottom→Top":  axisPos = 1.0 - fixture.positionY
            case "Radial Out":
                let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
                axisPos = min(1.0, sqrt(dx*dx + dy*dy) * 1.4142)
            case "Radial In":
                let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
                axisPos = 1.0 - min(1.0, sqrt(dx*dx + dy*dy) * 1.4142)
            default:            axisPos = fixture.positionX   // Left→Right
            }
        }

        let hue = (axisPos * spread + timeOffset).truncatingRemainder(dividingBy: 1.0)
        let (r, g, b) = hsvToRGB(h: hue, s: saturation, v: brightness)

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile, r: r, g: g, b: b)
        return result
    }
}
