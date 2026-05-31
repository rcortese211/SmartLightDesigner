import Foundation
import Observation

@Observable
final class DMXEngine {
    let outputManager: DMXOutputManager
    let cueEngine: CueEngine

    private(set) var universeData: [Int: [UInt8]] = [:]
    private var show: Show?
    private var startTime: Double = 0
    private var timer: Timer?
    private let registry = EffectRegistry.shared

    // External parameter overrides — audio/MIDI inputs can write here
    var parameterOverrides: [UUID: [String: ParameterValue]] = [:]

    init(outputManager: DMXOutputManager) {
        self.outputManager = outputManager
        self.cueEngine = CueEngine()
    }

    func start(show: Show) {
        self.show = show
        cueEngine.cues = show.cues
        startTime = Date().timeIntervalSinceReferenceDate
        let interval = 1.0 / 44.0
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
        outputManager.startAll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        outputManager.stopAll()
        // Zero all universes
        for key in universeData.keys {
            let zeros = Array(repeating: UInt8(0), count: 512)
            universeData[key] = zeros
            outputManager.send(universe: key, values: zeros)
        }
    }

    private func tick() {
        guard let show else { return }
        let time = Date().timeIntervalSinceReferenceDate - startTime
        cueEngine.updateFade(currentTime: Date().timeIntervalSinceReferenceDate)

        let activeLayers = cueEngine.activeLayers ?? show.layers

        // Initialise universe buffers
        let usedUniverses = Set(show.fixtures.map { $0.universe })
        var newUniverseData: [Int: [UInt8]] = [:]
        for u in usedUniverses {
            newUniverseData[u] = Array(repeating: 0, count: 512)
        }

        // Render each enabled layer (bottom-to-top compositing)
        for layer in activeLayers where layer.isEnabled {
            guard let effect = registry.effect(for: layer.effectId) else { continue }

            let fixtures: [Fixture]
            if layer.fixtureIds.isEmpty {
                fixtures = show.fixtures
            } else {
                fixtures = show.fixtures.filter { layer.fixtureIds.contains($0.id) }
            }

            var effectParams = layer.parameters
            // Merge any external overrides (audio/MIDI hook point)
            if let overrides = parameterOverrides[layer.id] {
                effectParams.merge(overrides) { _, new in new }
            }

            for fixture in fixtures {
                guard let profile = show.profile(for: fixture) else { continue }
                let rendered = effect.render(
                    fixture: fixture,
                    profile: profile,
                    parameters: effectParams,
                    time: time,
                    speed: layer.speed
                )
                guard var universe = newUniverseData[fixture.universe] else { continue }
                composite(
                    rendered, into: &universe,
                    startAddress: fixture.startAddress - 1,
                    opacity: layer.opacity,
                    blendMode: layer.blendMode
                )
                newUniverseData[fixture.universe] = universe
            }
        }

        universeData = newUniverseData
        for (universe, values) in newUniverseData {
            outputManager.send(universe: universe, values: values)
        }
    }

    private func composite(
        _ channels: FixtureChannels,
        into universe: inout [UInt8],
        startAddress: Int,
        opacity: Double,
        blendMode: DMXBlendMode
    ) {
        for (offset, srcByte) in channels {
            let idx = startAddress + offset
            guard idx >= 0 && idx < 512 else { continue }

            let src = Double(srcByte)
            let dst = Double(universe[idx])
            let a   = opacity

            // Normalise to 0-1 for blend math, scale back at end
            let s = src / 255.0, d = dst / 255.0
            let blended: Double
            switch blendMode {
            // Basic
            case .normal:       blended = s
            case .override:     blended = srcByte > 0 ? s : d
            // Darken
            case .darken:       blended = min(d, s)
            case .multiply:     blended = d * s
            case .colorBurn:    blended = s > 0 ? max(0, 1 - (1 - d) / s) : 0
            case .linearBurn:   blended = max(0, d + s - 1)
            // Lighten
            case .lighten:      blended = max(d, s)
            case .screen:       blended = 1 - (1 - d) * (1 - s)
            case .colorDodge:   blended = s < 1 ? min(1, d / (1 - s)) : 1
            case .linearDodge:  blended = min(1, d + s)
            // Contrast
            case .overlay:      blended = d < 0.5 ? 2*d*s : 1 - 2*(1-d)*(1-s)
            case .softLight:
                if s < 0.5 { blended = d - (1 - 2*s)*d*(1-d) }
                else        { let g = d < 0.25 ? ((16*d-12)*d+4)*d : sqrt(d)
                              blended = d + (2*s-1)*(g-d) }
            case .hardLight:    blended = s < 0.5 ? 2*d*s : 1 - 2*(1-d)*(1-s)
            case .vividLight:   blended = s < 0.5 ? (s > 0 ? max(0, 1-(1-d)/(2*s)) : 0) : (s < 1 ? min(1, d/(2*(1-s))) : 1)
            case .linearLight:  blended = max(0, min(1, d + 2*s - 1))
            case .pinLight:     blended = s < 0.5 ? min(d, 2*s) : max(d, 2*s-1)
            case .hardMix:      blended = (s < 0.5 ? max(0,1-(1-d)/(2*s)) : min(1,d/(2*(1-s)))) < 0.5 ? 0 : 1
            // Inversion
            case .difference:   blended = abs(d - s)
            case .exclusion:    blended = d + s - 2*d*s
            // Component
            case .subtract:     blended = max(0, d - s)
            case .divide:       blended = s > 0 ? min(1, d / s) : 1
            case .negativeMask: blended = s > 0 ? 0 : d
            }
            let result = blended * a + d * (1 - a)
            universe[idx] = UInt8(max(0, min(255, result * 255)))
        }
    }
}
