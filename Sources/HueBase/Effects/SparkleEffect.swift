import Foundation

struct SparkleEffect: Effect {
    let id = "sparkle"
    let name = "Sparkle"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "color", name: "Color", type: .color,
            defaultValue: .color(r: 1, g: 1, b: 1)
        ),
        EffectParameterDefinition(
            key: "density", name: "Density", type: .double(min: 0.01, max: 1.0),
            defaultValue: .double(0.3)
        ),
        EffectParameterDefinition(
            key: "decay", name: "Decay", type: .double(min: 0.1, max: 4.0),
            defaultValue: .double(0.8)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (r, g, b) = parameters["color"]?.colorValue ?? (1, 1, 1)
        let density = parameters["density"]?.doubleValue ?? 0.3
        let decay   = parameters["decay"]?.doubleValue ?? 0.8

        // Deterministic pseudo-random sparkle based on fixture ID + time bucket
        let bucketSize = 1.0 / (speed * 2.0 + 0.001)
        let timeBucket = Int(time / bucketSize)
        let fixtureHash = fixture.id.hashValue

        var rng = SeedableRNG(seed: UInt64(bitPattern: Int64(fixtureHash ^ timeBucket)))
        let sparkleValue = rng.nextDouble()
        let isActive = sparkleValue < density

        let decayPhase = (time.truncatingRemainder(dividingBy: bucketSize)) / bucketSize
        let brightness = isActive ? pow(1.0 - decayPhase, decay) : 0.0

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile, r: r * brightness, g: g * brightness, b: b * brightness)
        return result
    }
}

// Minimal deterministic RNG for sparkle without Foundation.random seeding
private struct SeedableRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func nextDouble() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 33) / Double(1 << 31)
    }
}
