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

    // A/B crossfader — 0.0 = full Program A, 1.0 = full Program B
    var crossfade: Double = 0
    var programBLayers: [Layer] = []

    // Timeline playback override — when set, takes priority over show.layers and cue engine
    var playbackLayers: [Layer]? = nil

    // Highlight override — applied after all other rendering; highest priority
    struct HighlightOverride {
        var selectedIDs: Set<UUID>
        var highlightRGB: (r: Double, g: Double, b: Double)
        var lowlightRGB:  (r: Double, g: Double, b: Double)
    }
    var highlightOverride: HighlightOverride? = nil

    // Persistent render buffers — zeroed and reused each tick to avoid per-frame heap allocation
    // @ObservationIgnored prevents 44 Hz SwiftUI redraws from internal buffer mutations
    @ObservationIgnored private var bufA: [Int: [UInt8]] = [:]
    @ObservationIgnored private var bufB: [Int: [UInt8]] = [:]
    private static let zerosBuffer: [UInt8] = Array(repeating: 0, count: 512)

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

    func update(show: Show) {
        self.show = show
        cueEngine.cues = show.cues
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        outputManager.stopAll()
        for key in universeData.keys {
            universeData[key] = Self.zerosBuffer
            outputManager.send(universe: key, values: Self.zerosBuffer)
        }
    }

    private func tick() {
        guard let show else { return }
        let time = Date().timeIntervalSinceReferenceDate - startTime
        cueEngine.updateFade(currentTime: Date().timeIntervalSinceReferenceDate)

        let aLayers = playbackLayers ?? cueEngine.activeLayers ?? show.layers

        if crossfade <= 0.001 {
            renderUniverses(layers: aLayers, show: show, time: time, into: &bufA)
            if let hl = highlightOverride { applyHighlight(hl, to: &bufA, show: show) }
            universeData = bufA
            for (universe, values) in bufA { outputManager.send(universe: universe, values: values) }
        } else if crossfade >= 0.999 {
            renderUniverses(layers: programBLayers, show: show, time: time, into: &bufA)
            if let hl = highlightOverride { applyHighlight(hl, to: &bufA, show: show) }
            universeData = bufA
            for (universe, values) in bufA { outputManager.send(universe: universe, values: values) }
        } else {
            renderUniverses(layers: aLayers, show: show, time: time, into: &bufA)
            renderUniverses(layers: programBLayers, show: show, time: time, into: &bufB)
            let fade = crossfade
            // Blend A and B in-place: remove each entry so aVal is sole owner (avoids CoW copy)
            for u in bufA.keys {
                var aVal = bufA.removeValue(forKey: u)!
                let b = bufB[u] ?? Self.zerosBuffer
                for i in 0..<512 {
                    aVal[i] = UInt8(Double(aVal[i]) * (1 - fade) + Double(b[i]) * fade)
                }
                bufA[u] = aVal
            }
            if let hl = highlightOverride { applyHighlight(hl, to: &bufA, show: show) }
            universeData = bufA
            for (universe, values) in bufA { outputManager.send(universe: universe, values: values) }
        }
    }

    private func renderUniverses(layers: [Layer], show: Show, time: Double, into data: inout [Int: [UInt8]]) {
        let usedUniverses = Set(show.fixtures.map { $0.universe })
        // Reuse existing buffers: remove from dict so the local var is sole owner (no CoW),
        // zero in place, then put back. New universes get the shared static zeros constant.
        for u in usedUniverses {
            if var buf = data.removeValue(forKey: u) {
                for i in 0..<512 { buf[i] = 0 }
                data[u] = buf
            } else {
                data[u] = Self.zerosBuffer
            }
        }

        for layer in layers where layer.isEnabled {
            guard let effect = registry.effect(for: layer.effectId) else { continue }
            let fixtures: [Fixture] = layer.fixtureIds.isEmpty
                ? show.fixtures
                : show.fixtures.filter { layer.fixtureIds.contains($0.id) }
            var effectParams = layer.parameters
            if let overrides = parameterOverrides[layer.id] {
                effectParams.merge(overrides) { _, new in new }
            }
            for fixture in fixtures {
                guard let profile = show.profile(for: fixture) else { continue }
                let effectFixture: Fixture
                if layer.zone.isFullCanvas {
                    effectFixture = fixture
                } else {
                    let z = layer.zone
                    guard z.contains(nx: fixture.positionX, ny: fixture.positionY) else { continue }
                    var f = fixture
                    f.positionX = (fixture.positionX - z.x) / z.width
                    f.positionY = (fixture.positionY - z.y) / z.height
                    effectFixture = f
                }
                let rendered = effect.render(fixture: effectFixture, profile: profile,
                                             parameters: effectParams, time: time, speed: layer.speed)
                guard var universe = data[fixture.universe] else { continue }
                composite(rendered, into: &universe,
                          startAddress: fixture.startAddress - 1,
                          opacity: layer.opacity, blendMode: layer.blendMode)
                data[fixture.universe] = universe
            }
        }
    }

    private func applyHighlight(_ hl: HighlightOverride, to data: inout [Int: [UInt8]], show: Show) {
        // Group fixtures by universe so each universe buffer is fetched/written back once, not per fixture
        var fixturesByUniverse: [Int: [Fixture]] = [:]
        for fixture in show.fixtures {
            guard data[fixture.universe] != nil else { continue }
            fixturesByUniverse[fixture.universe, default: []].append(fixture)
        }
        for (u, fixtures) in fixturesByUniverse {
            var universe = data[u]!
            for fixture in fixtures {
                guard let profile = show.profile(for: fixture) else { continue }
                let (r, g, b) = hl.selectedIDs.contains(fixture.id) ? hl.highlightRGB : hl.lowlightRGB
                let base = fixture.startAddress - 1
                for ch in profile.channels {
                    let idx = base + ch.offset
                    guard idx >= 0 && idx < 512 else { continue }
                    switch ch.name.lowercased() {
                    case "red",   "r": universe[idx] = UInt8(clamp01(r) * 255)
                    case "green", "g": universe[idx] = UInt8(clamp01(g) * 255)
                    case "blue",  "b": universe[idx] = UInt8(clamp01(b) * 255)
                    case "white", "w": universe[idx] = UInt8(clamp01(min(r, g, b)) * 255)
                    case "amber", "a": universe[idx] = UInt8(clamp01((r + g) / 2 * 0.7) * 255)
                    case "dimmer", "intensity", "master":
                        universe[idx] = UInt8(clamp01(max(r, g, b)) * 255)
                    default: universe[idx] = 0
                    }
                }
            }
            data[u] = universe
        }
    }

    private func clamp01(_ v: Double) -> Double { max(0, min(1, v)) }

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
