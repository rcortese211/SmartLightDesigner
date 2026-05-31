import Foundation

struct WaveEffect: Effect {
    let id = "wave"
    let name = "Wave"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_peak", name: "Peak Color", type: .color,
            defaultValue: .color(r: 1, g: 1, b: 1)
        ),
        EffectParameterDefinition(
            key: "color_trough", name: "Trough Color", type: .color,
            defaultValue: .color(r: 0, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "frequency", name: "Frequency", type: .double(min: 0.25, max: 8),
            defaultValue: .double(1.0)
        ),
        EffectParameterDefinition(
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top",
                                    "Diagonal↘",  "Diagonal↙",
                                    "Radial Out",  "Radial In"]),
            defaultValue: .string("Left→Right")
        ),
        EffectParameterDefinition(
            key: "shape", name: "Shape",
            type: .select(options: ["Sine", "Triangle", "Sawtooth"]),
            defaultValue: .string("Sine")
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (pr, pg, pb) = parameters["color_peak"]?.colorValue   ?? (1, 1, 1)
        let (tr, tg, tb) = parameters["color_trough"]?.colorValue ?? (0, 0, 0)
        let frequency    = parameters["frequency"]?.doubleValue ?? 1.0
        let dirStr       = parameters["direction"]?.stringValue ?? "Left→Right"
        let shape        = parameters["shape"]?.stringValue ?? "Sine"

        let axisPos: Double
        switch dirStr {
        case "Right→Left":  axisPos = 1.0 - fixture.positionX
        case "Top→Bottom":  axisPos = fixture.positionY
        case "Bottom→Top":  axisPos = 1.0 - fixture.positionY
        case "Diagonal↘":   axisPos = (fixture.positionX + fixture.positionY) / 2.0
        case "Diagonal↙":   axisPos = ((1 - fixture.positionX) + fixture.positionY) / 2.0
        case "Radial Out":
            let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
            axisPos = min(1, sqrt(dx*dx + dy*dy) * 1.4142)
        case "Radial In":
            let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
            axisPos = 1 - min(1, sqrt(dx*dx + dy*dy) * 1.4142)
        default:            axisPos = fixture.positionX
        }

        let phase = axisPos * frequency - time * speed * 0.3
        let t: Double
        switch shape {
        case "Triangle":
            let p = (phase * 2).truncatingRemainder(dividingBy: 2.0)
            let tp = p < 0 ? p + 2 : p
            t = tp < 1 ? tp : 2 - tp
        case "Sawtooth":
            let p = phase.truncatingRemainder(dividingBy: 1.0)
            t = p < 0 ? p + 1 : p
        default: // Sine
            t = (sin(phase * 2 * .pi) + 1) / 2
        }

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: tr + (pr - tr) * t,
               g: tg + (pg - tg) * t,
               b: tb + (pb - tb) * t)
        return result
    }
}
