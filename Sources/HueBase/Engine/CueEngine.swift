import Foundation
import Observation

@Observable
final class CueEngine {
    var cues: [Cue] = []
    var effectFolders: [EffectFolder] = []
    var currentIndex: Int = -1

    // Active layers fed into DMXEngine each tick (nil = freerun mode).
    // During a fade this holds the SOURCE state; DMXEngine blends source→target at the buffer level.
    private(set) var activeLayers: [Layer]? = nil

    // Exposed so DMXEngine can render both sides of a crossfade independently.
    private(set) var fadeSourceLayers: [Layer] = []
    private(set) var fadeTargetLayers: [Layer] = []
    private(set) var fadeStartTime: Double = 0
    private(set) var fadeDuration: Double = 0
    private(set) var isFading: Bool = false
    private var followTimer: Timer?

    /// Wall-clock date when the current fade began. Used by UI progress indicators.
    var fadeStartDate: Date { Date(timeIntervalSinceReferenceDate: fadeStartTime) }

    /// 0 = start of fade, 1 = complete. Computed from real time so it's always fresh.
    var fadeProgress: Double {
        guard isFading, fadeDuration > 0 else { return 0 }
        return min((CACurrentMediaTime() - fadeStartTime) / fadeDuration, 1.0)
    }

    var currentCue: Cue? {
        guard currentIndex >= 0 && currentIndex < cues.count else { return nil }
        return cues[currentIndex]
    }

    func go() {
        let next = currentIndex + 1
        guard next < cues.count else { return }
        transition(to: next)
    }

    func back() {
        let prev = currentIndex - 1
        guard prev >= 0 else { return }
        transition(to: prev)
    }

    func jump(to index: Int) {
        guard index >= 0 && index < cues.count else { return }
        transition(to: index)
    }

    func exitCueMode() {
        activeLayers = nil
        currentIndex = -1
        isFading = false
        followTimer?.invalidate()
    }

    private func transition(to index: Int) {
        followTimer?.invalidate()
        followTimer = nil

        let cue = cues[index]

        // Resolve target layers: palette ref wins over snapshot if the palette still exists
        let targetLayers: [Layer]
        if let ref = cue.paletteRef,
           let folder = effectFolders.first(where: { $0.id == ref.folderID }),
           let palette = folder.palettes.first(where: { $0.id == ref.paletteID }) {
            targetLayers = palette.layers
        } else {
            targetLayers = cue.layerSnapshot
        }

        // Source is whatever was last rendered (or the new target if this is the first cue)
        fadeSourceLayers = activeLayers ?? []
        fadeTargetLayers = targetLayers
        fadeDuration = cue.fadeInTime
        fadeStartTime = CACurrentMediaTime()
        isFading = fadeDuration > 0
        currentIndex = index

        if !isFading {
            // Instant snap: no crossfade needed
            activeLayers = targetLayers
        }
        // When fading, activeLayers keeps the source state until the fade is done.
        // DMXEngine renders both fadeSourceLayers and fadeTargetLayers and blends them.

        if let followTime = cue.followTime, followTime > 0 {
            followTimer = Timer.scheduledTimer(withTimeInterval: followTime, repeats: false) { [weak self] _ in
                self?.go()
            }
        }
    }

    /// Called every DMX tick. Marks the fade complete when the time has elapsed.
    /// Actual blending is done at the DMX buffer level in DMXEngine.
    func updateFade(currentTime: Double) {
        guard isFading, fadeDuration > 0 else { return }
        if currentTime - fadeStartTime >= fadeDuration {
            activeLayers = fadeTargetLayers
            isFading = false
        }
    }
}

// CACurrentMediaTime stub — on macOS this is QuartzCore, but we use Foundation's Date
private func CACurrentMediaTime() -> Double {
    return Date().timeIntervalSinceReferenceDate
}
