import Foundation

// A single beam of light that scans back and forth across the rig.
struct ScannerEffect: Effect {
    let id = "scanner"
    let name = "Scanner"

    let parameterDefinitions: [EffectParameterDefinition] = [
        EffectParameterDefinition(
            key: "beam_color", name: "Beam Color", type: .color,
            defaultValue: .color(r: 1, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "bg_color", name: "Background", type: .color,
            defaultValue: .color(r: 0, g: 0, b: 0)
        ),
        EffectParameterDefinition(
            key: "beam_width", name: "Beam Width", type: .double(min: 0.01, max: 0.5),
            defaultValue: .double(0.08)
        ),
        EffectParameterDefinition(
            key: "falloff", name: "Falloff", type: .double(min: 0.5, max: 6),
            defaultValue: .double(2.0)
        ),
        EffectParameterDefinition(
            key: "axis", name: "Axis",
            type: .select(options: ["Horizontal", "Vertical", "Diagonal↘"]),
            defaultValue: .string("Horizontal")
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (br, bg, bb) = parameters["beam_color"]?.colorValue ?? (1, 0, 0)
        let (gr, gg, gb) = parameters["bg_color"]?.colorValue   ?? (0, 0, 0)
        let beamWidth = max(0.01, parameters["beam_width"]?.doubleValue ?? 0.08)
        let falloff   = parameters["falloff"]?.doubleValue ?? 2.0
        let axis      = parameters["axis"]?.stringValue ?? "Horizontal"

        let axisPos: Double
        switch axis {
        case "Vertical":  axisPos = fixture.positionY
        case "Diagonal↘": axisPos = (fixture.positionX + fixture.positionY) / 2
        default:          axisPos = fixture.positionX
        }

        // Triangle wave bounce 0→1→0
        let raw     = (time * speed * 0.2).truncatingRemainder(dividingBy: 2.0)
        let scanPos = raw < 1 ? raw : 2 - raw

        let dist = abs(axisPos - scanPos)
        let intensity = pow(max(0, 1 - dist / beamWidth), falloff)

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: gr + (br - gr) * intensity,
               g: gg + (bg - gg) * intensity,
               b: gb + (bb - gb) * intensity)
        return result
    }
}
