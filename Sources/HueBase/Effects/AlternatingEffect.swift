import Foundation

// Even/odd fixture groups in alternating colors, with optional scrolling.
struct AlternatingEffect: Effect {
    let id = "alternating"
    let name = "Alternating"

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
            key: "group_size", name: "Group Size", type: .double(min: 1, max: 8),
            defaultValue: .double(1.0)
        ),
        EffectParameterDefinition(
            key: "axis", name: "Axis",
            type: .select(options: ["Horizontal", "Vertical",
                                    "Diagonal↘", "Checkerboard"]),
            defaultValue: .string("Horizontal")
        ),
        EffectParameterDefinition(
            key: "scroll", name: "Scroll", type: .bool,
            defaultValue: .bool(true)
        )
    ]

    func render(
        fixture: Fixture, profile: FixtureProfile,
        parameters: [String: ParameterValue], time: Double, speed: Double
    ) -> FixtureChannels {
        let (ar, ag, ab) = parameters["color_a"]?.colorValue ?? (1, 0, 0)
        let (br, bg, bb) = parameters["color_b"]?.colorValue ?? (0, 0, 1)
        let groupSize = max(1.0, parameters["group_size"]?.doubleValue ?? 1.0)
        let axis      = parameters["axis"]?.stringValue ?? "Horizontal"
        let scroll    = parameters["scroll"]?.boolValue ?? true

        let slotOffset = scroll ? (time * speed * 0.2).truncatingRemainder(dividingBy: 1.0) : 0.0

        let slotIndex: Int
        switch axis {
        case "Vertical":
            slotIndex = Int((fixture.positionY + slotOffset) * groupSize * 20)
        case "Diagonal↘":
            slotIndex = Int(((fixture.positionX + fixture.positionY) / 2 + slotOffset) * groupSize * 20)
        case "Checkerboard":
            let xi = Int(fixture.positionX * 10)
            let yi = Int(fixture.positionY * 10)
            let scrollBucket = Int(slotOffset * 10)
            slotIndex = (xi + yi + scrollBucket)
        default: // Horizontal
            slotIndex = Int((fixture.positionX + slotOffset) * groupSize * 20)
        }

        let useA = (slotIndex / Int(max(1, groupSize))) % 2 == 0

        var result: FixtureChannels = [:]
        setRGB(&result, profile: profile,
               r: useA ? ar : br,
               g: useA ? ag : bg,
               b: useA ? ab : bb)
        return result
    }
}
