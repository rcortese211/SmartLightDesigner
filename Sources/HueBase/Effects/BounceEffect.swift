import Foundation

// Like Chase but the wave front ping-pongs back and forth instead of wrapping.
struct BounceEffect: Effect {
    let id = "bounce"
    let name = "Bounce"

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
            defaultValue: .double(4.0)
        ),
        EffectParameterDefinition(
            key: "axis", name: "Axis",
            type: .select(options: ["Horizontal", "Vertical", "Diagonal↘", "Radial"]),
            defaultValue: .string("Horizontal")
        ),
        EffectParameterDefinition(
            key: "softness", name: "Softness", type: .double(min: 0, max: 1),
            defaultValue: .double(0.0)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (onR, onG, onB)   = parameters["color_on"]?.colorValue  ?? (1, 1, 1)
        let (offR, offG, offB) = parameters["color_off"]?.colorValue ?? (0, 0, 0)
        let density  = max(1.0, parameters["density"]?.doubleValue ?? 4.0)
        let axis     = parameters["axis"]?.stringValue ?? "Horizontal"
        let softness = parameters["softness"]?.doubleValue ?? 0.0

        let axisPos: Double
        switch axis {
        case "Vertical":   axisPos = fixture.positionY
        case "Diagonal↘":  axisPos = (fixture.positionX + fixture.positionY) / 2
        case "Radial":
            let dx = fixture.positionX - 0.5, dy = fixture.positionY - 0.5
            axisPos = min(1, sqrt(dx*dx + dy*dy) * 1.4142)
        default:           axisPos = fixture.positionX
        }

        // Triangle wave: 0→1→0→1→…
        let raw = (time * speed * 0.25).truncatingRemainder(dividingBy: 2.0)
        let wavePos = raw < 1 ? raw : 2 - raw   // bounce between 0 and 1

        let windowSize = 1.0 / density
        let dist = abs(axisPos - wavePos)

        let brightness: Double
        if softness < 0.01 {
            brightness = dist < windowSize ? 1 : 0
        } else {
            brightness = max(0, 1 - dist / (windowSize * (1 + softness * 3)))
        }

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: offR + (onR - offR) * brightness,
               g: offG + (onG - offG) * brightness,
               b: offB + (onB - offB) * brightness)
        return result
    }
}
