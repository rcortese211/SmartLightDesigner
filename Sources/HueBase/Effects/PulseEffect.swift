import Foundation

struct PulseEffect: Effect {
    let id = "pulse"
    let name = "Pulse"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color", name: "Color", type: .color,
            defaultValue: .color(r: 1, g: 0.4, b: 0)
        ),
        EffectParameterDefinition(
            key: "min_brightness", name: "Min Brightness", type: .double(min: 0, max: 1),
            defaultValue: .double(0.0)
        ),
        EffectParameterDefinition(
            key: "waveform", name: "Waveform",
            type: .select(options: ["Sine", "Triangle", "Sawtooth", "Square"]),
            defaultValue: .string("Sine")
        ),
        EffectParameterDefinition(
            key: "spatial_spread", name: "Spatial Spread", type: .double(min: 0, max: 4),
            defaultValue: .double(0.0)
        ),
        EffectParameterDefinition(
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top",
                                    "Radial Out", "Radial In"]),
            defaultValue: .string("Left→Right")
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (r, g, b)   = parameters["color"]?.colorValue ?? (1, 0.4, 0)
        let minBri      = parameters["min_brightness"]?.doubleValue ?? 0.0
        let waveform    = parameters["waveform"]?.stringValue ?? "Sine"
        let spread      = parameters["spatial_spread"]?.doubleValue ?? 0.0
        let dirStr      = parameters["direction"]?.stringValue ?? "Left→Right"

        let axisPos: Double
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
        default:            axisPos = fixture.positionX
        }

        let phase = time * speed * 0.5 + axisPos * spread
        let bri: Double
        switch waveform {
        case "Triangle":
            let t = (phase * 2).truncatingRemainder(dividingBy: 2.0)
            bri = t < 1 ? t : 2 - t
        case "Sawtooth":
            bri = (phase).truncatingRemainder(dividingBy: 1.0)
        case "Square":
            bri = phase.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1 : 0
        default: // Sine
            bri = (sin(phase * 2 * .pi) + 1) / 2
        }

        let level = minBri + bri * (1 - minBri)
        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile, r: r * level, g: g * level, b: b * level)
        return result
    }
}
