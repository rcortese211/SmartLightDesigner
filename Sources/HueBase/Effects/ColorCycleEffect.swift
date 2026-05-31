import Foundation

// Cycles smoothly through a user-defined list of colors.
// Unlike Rainbow (which always uses the full HSB spectrum), this effect
// uses exactly the colors the user places in the stack — useful for
// brand colors, specific gel looks, or thematic palettes.
struct ColorCycleEffect: Effect {
    let id = "color_cycle"
    let name = "Color Cycle"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "colors", name: "Color Stack", type: .colorList,
            defaultValue: .colorList([
                (r: 1, g: 0, b: 0),
                (r: 0, g: 1, b: 0),
                (r: 0, g: 0, b: 1)
            ])
        ),
        EffectParameterDefinition(
            key: "spatial_offset", name: "Spatial Offset", type: .double(min: 0, max: 4),
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
            key: "interpolation", name: "Interpolation",
            type: .select(options: ["Smooth", "Stepped"]),
            defaultValue: .string("Smooth")
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let colors = parameters["colors"]?.colorListValue ?? [
            (r: 1, g: 0, b: 0), (r: 0, g: 1, b: 0), (r: 0, g: 0, b: 1)
        ]
        guard !colors.isEmpty else {
            var result: FixtureChannels = [:]
            setRGB(&result, profile: profile, r: 0, g: 0, b: 0)
            return result
        }
        if colors.count == 1 {
            var result: FixtureChannels = [:]
            setRGB(&result, profile: profile, r: colors[0].r, g: colors[0].g, b: colors[0].b)
            return result
        }

        let spatialOffset = parameters["spatial_offset"]?.doubleValue ?? 1.0
        let dirStr        = parameters["direction"]?.stringValue ?? "Left→Right"
        let interp        = parameters["interpolation"]?.stringValue ?? "Smooth"

        let axisPos: Double
        switch dirStr {
        case "Right→Left":  axisPos = 1 - fixture.positionX
        case "Top→Bottom":  axisPos = fixture.positionY
        case "Bottom→Top":  axisPos = 1 - fixture.positionY
        case "Radial Out":
            let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
            axisPos = min(1, sqrt(dx*dx + dy*dy) * 1.4142)
        case "Radial In":
            let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
            axisPos = 1 - min(1, sqrt(dx*dx + dy*dy) * 1.4142)
        default:            axisPos = fixture.positionX
        }

        let n = Double(colors.count)
        let t = (time * speed * 0.15 + axisPos * spatialOffset / n)
            .truncatingRemainder(dividingBy: 1.0)
        let scaled = ((t < 0 ? t + 1 : t)) * n

        let idxA = Int(scaled) % colors.count
        let idxB = (idxA + 1) % colors.count
        let frac = scaled - Double(Int(scaled))
        let blend = interp == "Stepped" ? 0.0 : frac

        let a = colors[idxA], b = colors[idxB]
        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: a.r + (b.r - a.r) * blend,
               g: a.g + (b.g - a.g) * blend,
               b: a.b + (b.b - a.b) * blend)
        return result
    }
}
