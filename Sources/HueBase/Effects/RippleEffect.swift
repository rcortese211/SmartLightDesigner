import Foundation

// Concentric rings expanding outward from a configurable origin point.
struct RippleEffect: Effect {
    let id = "ripple"
    let name = "Ripple"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color_peak", name: "Ring Color", type: .color,
            defaultValue: .color(r: 0, g: 0.6, b: 1)
        ),
        EffectParameterDefinition(
            key: "color_trough", name: "Background", type: .color,
            defaultValue: .color(r: 0, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "frequency", name: "Ring Frequency", type: .double(min: 0.5, max: 8),
            defaultValue: .double(2.0)
        ),
        EffectParameterDefinition(
            key: "origin_x", name: "Origin X", type: .double(min: 0, max: 1),
            defaultValue: .double(0.5)
        ),
        EffectParameterDefinition(
            key: "origin_y", name: "Origin Y", type: .double(min: 0, max: 1),
            defaultValue: .double(0.5)
        ),
        EffectParameterDefinition(
            key: "sharpness", name: "Sharpness", type: .double(min: 1, max: 6),
            defaultValue: .double(2.0)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (pr, pg, pb) = parameters["color_peak"]?.colorValue   ?? (0, 0.6, 1)
        let (tr, tg, tb) = parameters["color_trough"]?.colorValue ?? (0, 0, 0)
        let frequency = parameters["frequency"]?.doubleValue ?? 2.0
        let ox        = parameters["origin_x"]?.doubleValue ?? 0.5
        let oy        = parameters["origin_y"]?.doubleValue ?? 0.5
        let sharpness = parameters["sharpness"]?.doubleValue ?? 2.0

        let dx = fixture.positionX - ox
        let dy = fixture.positionY - oy
        let radius = sqrt(dx*dx + dy*dy)   // 0 at origin, ~0.7 at corners

        let wave = (sin((radius * frequency - time * speed * 0.4) * 2 * .pi) + 1) / 2
        let t = pow(wave, sharpness)

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: tr + (pr - tr) * t,
               g: tg + (pg - tg) * t,
               b: tb + (pb - tb) * t)
        return result
    }
}
