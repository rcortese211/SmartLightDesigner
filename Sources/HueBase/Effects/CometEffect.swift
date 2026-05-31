import Foundation

struct CometEffect: Effect {
    let id = "comet"
    let name = "Comet"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "head_color", name: "Head Color", type: .color,
            defaultValue: .color(r: 1, g: 1, b: 1)
        ),
        EffectParameterDefinition(
            key: "tail_color", name: "Tail Color", type: .color,
            defaultValue: .color(r: 0.1, g: 0.05, b: 0.4)
        ),
        EffectParameterDefinition(
            key: "tail_length", name: "Tail Length", type: .double(min: 0.02, max: 0.8),
            defaultValue: .double(0.25)
        ),
        EffectParameterDefinition(
            key: "tail_curve", name: "Tail Curve", type: .double(min: 0.5, max: 4),
            defaultValue: .double(1.5)
        ),
        EffectParameterDefinition(
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top",
                                    "Diagonal↘",  "Diagonal↙"]),
            defaultValue: .string("Left→Right")
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (hr, hg, hb) = parameters["head_color"]?.colorValue ?? (1, 1, 1)
        let (tr, tg, tb) = parameters["tail_color"]?.colorValue ?? (0.1, 0.05, 0.4)
        let tailLen  = max(0.02, parameters["tail_length"]?.doubleValue ?? 0.25)
        let curve    = parameters["tail_curve"]?.doubleValue ?? 1.5
        let dirStr   = parameters["direction"]?.stringValue ?? "Left→Right"

        let axisPos: Double
        switch dirStr {
        case "Right→Left":  axisPos = 1 - fixture.positionX
        case "Top→Bottom":  axisPos = fixture.positionY
        case "Bottom→Top":  axisPos = 1 - fixture.positionY
        case "Diagonal↘":   axisPos = (fixture.positionX + fixture.positionY) / 2
        case "Diagonal↙":   axisPos = ((1 - fixture.positionX) + fixture.positionY) / 2
        default:            axisPos = fixture.positionX
        }

        let headPos = (time * speed * 0.25).truncatingRemainder(dividingBy: 1.0)
        // Distance behind the head (wrapping)
        let behindDist = (headPos - axisPos + 1.0).truncatingRemainder(dividingBy: 1.0)

        let brightness: Double
        if behindDist < 0.01 {
            // At the head
            brightness = 1.0
        } else if behindDist < tailLen {
            brightness = pow(1.0 - behindDist / tailLen, curve)
        } else {
            brightness = 0.0
        }

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: tr + (hr - tr) * brightness,
               g: tg + (hg - tg) * brightness,
               b: tb + (hb - tb) * brightness)
        return result
    }
}
