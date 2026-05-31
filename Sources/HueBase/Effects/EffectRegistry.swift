import Foundation

final class EffectRegistry {
    static let shared = EffectRegistry()

    private var effects: [String: any Effect] = [:]

    private init() {
        register(ColorFillEffect())
        register(ColorMorphEffect())
        register(GradientEffect())
        register(ChaseEffect())
        register(BounceEffect())
        register(ScannerEffect())
        register(SegmentEffect())
        register(StrobeEffect())
        register(PulseEffect())
        register(WaveEffect())
        register(RainbowEffect())
        register(RippleEffect())
        register(PlasmaEffect())
        register(FireEffect())
        register(SparkleEffect())
        register(TwinkleEffect())
        register(AlternatingEffect())
    }

    func register(_ effect: some Effect) {
        effects[effect.id] = effect
    }

    func effect(for id: String) -> (any Effect)? {
        effects[id]
    }

    var allEffects: [(id: String, name: String)] {
        effects.values.map { (id: $0.id, name: $0.name) }
            .sorted { $0.name < $1.name }
    }

    func defaultParameters(for effectId: String) -> [String: ParameterValue] {
        guard let effect = effects[effectId] else { return [:] }
        return Dictionary(uniqueKeysWithValues: effect.parameterDefinitions.map {
            ($0.key, $0.defaultValue)
        })
    }
}
