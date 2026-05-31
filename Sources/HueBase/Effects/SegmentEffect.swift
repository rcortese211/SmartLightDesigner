import Foundation

// Divides the rig into alternating colored blocks that can scroll.
struct SegmentEffect: Effect {
    let id = "segment"
    let name = "Segments"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_a", name: "Color A", type: .color,
            defaultValue: .color(r: 1, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "color_b", name: "Color B", type: .color,
            defaultValue: .color(r: 0, g: 0, b: 1)
        ),
        EffectParameterDefinition(
            key: "count", name: "Segment Count", type: .double(min: 1, max: 16),
            defaultValue: .double(4.0)
        ),
        EffectParameterDefinition(
            key: "direction", name: "Direction",
            type: .select(options: ["Left→Right", "Right→Left",
                                    "Top→Bottom", "Bottom→Top",
                                    "Diagonal↘"]),
            defaultValue: .string("Left→Right")
        ),
        EffectParameterDefinition(
            key: "softness", name: "Edge Softness", type: .double(min: 0, max: 1),
            defaultValue: .double(0.0)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (ar, ag, ab) = parameters["color_a"]?.colorValue ?? (1, 0, 0)
        let (br, bg, bb) = parameters["color_b"]?.colorValue ?? (0, 0, 1)
        let count     = max(1.0, parameters["count"]?.doubleValue ?? 4.0)
        let dirStr    = parameters["direction"]?.stringValue ?? "Left→Right"
        let softness  = parameters["softness"]?.doubleValue ?? 0.0

        let axisPos: Double
        switch dirStr {
        case "Right→Left":  axisPos = 1 - fixture.positionX
        case "Top→Bottom":  axisPos = fixture.positionY
        case "Bottom→Top":  axisPos = 1 - fixture.positionY
        case "Diagonal↘":   axisPos = (fixture.positionX + fixture.positionY) / 2
        default:            axisPos = fixture.positionX
        }

        let scroll = (time * speed * 0.15).truncatingRemainder(dividingBy: 1.0)
        let pos    = (axisPos + scroll) * count
        let frac   = pos.truncatingRemainder(dividingBy: 1.0)

        let blend: Double
        if softness < 0.01 {
            blend = Int(pos) % 2 == 0 ? 0 : 1
        } else {
            let edge = softness * 0.5
            if frac < edge {
                blend = Int(pos) % 2 == 0 ? frac / edge : 1 - frac / edge
            } else if frac > 1 - edge {
                let f = (frac - (1 - edge)) / edge
                blend = Int(pos) % 2 == 0 ? 1 - f : f
            } else {
                blend = Int(pos) % 2 == 0 ? 0 : 1
            }
        }

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: ar + (br - ar) * blend,
               g: ag + (bg - ag) * blend,
               b: ab + (bb - ab) * blend)
        return result
    }
}
