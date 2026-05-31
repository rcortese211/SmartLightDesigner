import Foundation

// Each fixture independently oscillates at a randomised rate and phase,
// producing a soft twinkling star field.  Unlike Sparkle, transitions are
// smooth sine-based fades rather than hard on/off buckets.
struct TwinkleEffect: Effect {
    let id = "twinkle"
    let name = "Twinkle"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color", name: "Color", type: .color,
            defaultValue: .color(r: 1, g: 1, b: 1)
        ),
        EffectParameterDefinition(
            key: "bg_color", name: "Background", type: .color,
            defaultValue: .color(r: 0, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "density", name: "Density", type: .double(min: 0.1, max: 1),
            defaultValue: .double(0.5)
        ),
        EffectParameterDefinition(
            key: "rate_spread", name: "Rate Spread", type: .double(min: 0, max: 1),
            defaultValue: .double(0.6)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (r, g, b)    = parameters["color"]?.colorValue    ?? (1, 1, 1)
        let (gr, gg, gb) = parameters["bg_color"]?.colorValue ?? (0, 0, 0)
        let density    = parameters["density"]?.doubleValue    ?? 0.5
        let rateSpread = parameters["rate_spread"]?.doubleValue ?? 0.6

        let fixtureHash = fixture.id.hashValue
        var rng = TwinkleRNG(seed: UInt64(bitPattern: Int64(fixtureHash)))
        let phase = rng.nextDouble()                              // per-fixture random phase
        let rate  = 1.0 + rng.nextDouble() * rateSpread * 3.0   // per-fixture rate variation

        let wave = sin(2 * .pi * (time * speed * 0.5 * rate + phase))
        // Rectify and raise to power: controls what fraction of the cycle is bright
        let exponent = 1.0 / max(0.05, density)
        let brightness = pow(max(0, wave), exponent)

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: gr + (r - gr) * brightness,
               g: gg + (g - gg) * brightness,
               b: gb + (b - gb) * brightness)
        return result
    }
}

private struct TwinkleRNG {
    private var state: UInt64
    init(seed: UInt64) {
        state = seed &* 6364136223846793005 &+ 1442695040888963407
        _ = next()   // warm up
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 33) / Double(1 << 31)
    }
}
