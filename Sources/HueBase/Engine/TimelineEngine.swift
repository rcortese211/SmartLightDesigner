import Foundation
import Observation

@Observable
final class TimelineEngine {
    var playheadTime: Double = 0
    var isPlaying: Bool = false

    private var timerSource: DispatchSourceTimer?
    private var lastTickDate: Date = Date()

    weak var appState: AppState?

    var totalDuration: Double {
        guard let appState else { return 120 }
        let trackEnd = appState.show.timeline.tracks
            .flatMap(\.clips).map(\.endTime).max() ?? 0
        let audioEnd = appState.show.timeline.audioClip
            .map { $0.startTime + $0.fileDuration } ?? 0
        return max(60, trackEnd + 10, audioEnd + 10)
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        lastTickDate = Date()
        startTimer()
        appState?.audioPlayer.play(from: playheadTime)
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        stopTimer()
        appState?.audioPlayer.pause()
    }

    func stop() {
        isPlaying = false
        stopTimer()
        playheadTime = 0
        appState?.engine.playbackLayers = nil
        appState?.audioPlayer.stop()
    }

    func seek(to time: Double) {
        let wasPlaying = isPlaying
        if wasPlaying { stopTimer(); appState?.audioPlayer.stop() }
        playheadTime = max(0, time)
        if wasPlaying {
            lastTickDate = Date()
            startTimer()
            appState?.audioPlayer.play(from: playheadTime)
        }
    }

    // MARK: - Private

    private func startTimer() {
        let src = DispatchSource.makeTimerSource(flags: [], queue: .main)
        src.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(1))
        src.setEventHandler { [weak self] in self?.tick() }
        src.resume()
        timerSource = src
    }

    private func stopTimer() {
        timerSource?.cancel()
        timerSource = nil
    }

    private func tick() {
        guard let appState, isPlaying else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastTickDate)
        lastTickDate = now
        playheadTime += dt

        let dur = totalDuration
        if playheadTime >= dur {
            if appState.show.timeline.loop {
                playheadTime = 0
                appState.audioPlayer.play(from: 0)
            } else {
                isPlaying = false
                stopTimer()
                playheadTime = 0
                appState.engine.playbackLayers = nil
                appState.audioPlayer.stop()
                return
            }
        }

        // Build merged layer list from all active clips
        var merged: [Layer] = []
        for track in appState.show.timeline.tracks where !track.isMuted {
            for clip in track.clips {
                let t = playheadTime
                guard t >= clip.startTime && t < clip.endTime else { continue }
                let elapsed = t - clip.startTime
                let remaining = clip.endTime - t
                var clipOpacity = track.opacity
                if clip.fadeInDuration > 0 && elapsed < clip.fadeInDuration {
                    clipOpacity *= elapsed / clip.fadeInDuration
                }
                if clip.fadeOutDuration > 0 && remaining < clip.fadeOutDuration {
                    clipOpacity *= remaining / clip.fadeOutDuration
                }
                for var layer in clip.layers {
                    layer.opacity = layer.opacity * clipOpacity
                    merged.append(layer)
                }
            }
        }
        appState.engine.playbackLayers = merged.isEmpty ? nil : merged
    }
}
