import Foundation
import Observation

@Observable
final class CueEngine {
    var cues: [Cue] = []
    var currentIndex: Int = -1

    // Active layers fed into DMXEngine each tick.
    // nil means "use show.layers directly" (freerun mode).
    private(set) var activeLayers: [Layer]? = nil

    private var fadeStartLayers: [Layer] = []
    private var fadeTargetLayers: [Layer] = []
    private var fadeStartTime: Double = 0
    private var fadeDuration: Double = 0
    private var isFading: Bool = false
    private var followTimer: Timer?

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
        fadeStartLayers = activeLayers ?? cue.layerSnapshot
        fadeTargetLayers = cue.layerSnapshot
        fadeDuration = cue.fadeInTime
        fadeStartTime = CACurrentMediaTime()
        isFading = fadeDuration > 0
        currentIndex = index

        if !isFading {
            activeLayers = fadeTargetLayers
        }

        if let followTime = cue.followTime, followTime > 0 {
            followTimer = Timer.scheduledTimer(withTimeInterval: followTime, repeats: false) { [weak self] _ in
                self?.go()
            }
        }
    }

    func updateFade(currentTime: Double) {
        guard isFading, fadeDuration > 0 else { return }
        let elapsed = currentTime - fadeStartTime
        let t = min(elapsed / fadeDuration, 1.0)

        if t >= 1.0 {
            activeLayers = fadeTargetLayers
            isFading = false
            return
        }

        // Interpolate layer opacities between snapshots
        var blended: [Layer] = fadeTargetLayers
        for i in blended.indices {
            let targetOpacity = fadeTargetLayers[i].opacity
            let srcOpacity: Double
            if i < fadeStartLayers.count {
                srcOpacity = fadeStartLayers[i].opacity
            } else {
                srcOpacity = 0
            }
            blended[i].opacity = srcOpacity + (targetOpacity - srcOpacity) * t
        }
        activeLayers = blended
    }
}

// CACurrentMediaTime stub — on macOS this is QuartzCore, but we use Foundation's Date
private func CACurrentMediaTime() -> Double {
    return Date().timeIntervalSinceReferenceDate
}
