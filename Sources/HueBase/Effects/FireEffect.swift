import Foundation

struct FireEffect: Effect {
    let id = "fire"
    let name = "Fire"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "base_color", name: "Base Color", type: .color,
            defaultValue: .color(r: 1.0, g: 0.18, b: 0.0)
        ),
        EffectParameterDefinition(
            key: "peak_color", name: "Peak Color", type: .color,
            defaultValue: .color(r: 1.0, g: 0.85, b: 0.1)
        ),
        EffectParameterDefinition(
            key: "flicker", name: "Flicker Amount", type: .double(min: 0, max: 1),
            defaultValue: .double(0.7)
        ),
        EffectParameterDefinition(
            key: "base_level", name: "Base Level", type: .double(min: 0, max: 1),
            defaultValue: .double(0.3)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (br, bg, bb) = parameters["base_color"]?.colorValue ?? (1.0, 0.18, 0.0)
        let (pr, pg, pb) = parameters["peak_color"]?.colorValue ?? (1.0, 0.85, 0.1)
        let flicker   = parameters["flicker"]?.doubleValue ?? 0.7
        let baseLevel = parameters["base_level"]?.doubleValue ?? 0.3

        // Two time-slices of noise interpolated together
        let t = time * speed
        let bucket0 = Int(t * 8)
        let bucket1 = bucket0 + 1
        let interp  = (t * 8).truncatingRemainder(dividingBy: 1.0)

        let fixtureHash = fixture.id.hashValue
        let v0 = fireNoise(fixtureHash: fixtureHash, bucket: bucket0)
        let v1 = fireNoise(fixtureHash: fixtureHash, bucket: bucket1)
        let raw = v0 + (v1 - v0) * interp

        let heat = baseLevel + raw * flicker * (1 - baseLevel)

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: br + (pr - br) * heat,
               g: bg + (pg - bg) * heat,
               b: bb + (pb - bb) * heat)
        return result
    }

    private func fireNoise(fixtureHash: Int, bucket: Int) -> Double {
        var s = UInt64(bitPattern: Int64(fixtureHash ^ (bucket &* 2654435761)))
        s ^= s >> 33
        s = s &* 0xff51afd7ed558ccd
        s ^= s >> 33
        s = s &* 0xc4ceb9fe1a85ec53
        s ^= s >> 33
        return Double(s >> 33) / Double(1 << 31)
    }
}
