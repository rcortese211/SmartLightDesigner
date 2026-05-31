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
        RunLoop.main.add(timer!, forMode: .common)
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
        blendMode: BlendMode
    ) {
        for (offset, srcByte) in channels {
            let idx = startAddress + offset
            guard idx >= 0 && idx < 512 else { continue }

            let src = Double(srcByte)
            let dst = Double(universe[idx])
            let a   = opacity

            let result: Double
            switch blendMode {
            case .normal:
                result = src * a + dst * (1 - a)
            case .add:
                result = min(255, dst + src * a)
            case .subtract:
                result = max(0, dst - src * a)
            case .multiply:
                result = dst * (1 - a) + (dst * src / 255) * a
            case .screen:
                let screened = 255 - (255 - dst) * (255 - src) / 255
                result = dst * (1 - a) + screened * a
            case .override:
                result = srcByte > 0 ? (src * a + dst * (1 - a)) : dst
            }
            universe[idx] = UInt8(max(0, min(255, result)))
        }
    }
}
