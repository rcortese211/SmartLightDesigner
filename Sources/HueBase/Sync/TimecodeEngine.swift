import Foundation
import Observation

/// Central timecode engine. Accepts SMPTE (via Art-Net) and HueBase Network TC,
/// runs an internal clock when neither is active, and drives the cue timeline.
@Observable
final class TimecodeEngine {
    // Current position
    private(set) var current: SMPTETimecode = .zero
    private(set) var isRunning: Bool = false
    private(set) var source: TimecodeSource = .internal_

    enum TimecodeSource: String {
        case internal_ = "Internal"
        case smpte     = "SMPTE / Art-Net"
        case network   = "Network Sync"
    }

    // Internal clock
    private var internalStart: Double = 0
    private var internalOffset: Double = 0
    private var ticker: Timer?
    var frameRate: TimecodeFrameRate = .fps25

    // Callbacks — CueEngine hooks in here to follow timecode
    var onTimecodeUpdate: ((SMPTETimecode) -> Void)?

    // MARK: - Internal transport

    func play() {
        guard source == .internal_ else { return }
        internalStart = Date().timeIntervalSinceReferenceDate - internalOffset
        isRunning = true
        startTicker()
    }

    func stop() {
        isRunning = false
        ticker?.invalidate()
        ticker = nil
    }

    func pause() {
        internalOffset = Date().timeIntervalSinceReferenceDate - internalStart
        isRunning = false
        ticker?.invalidate()
        ticker = nil
    }

    func locate(to tc: SMPTETimecode) {
        internalOffset = tc.totalSeconds
        if isRunning {
            internalStart = Date().timeIntervalSinceReferenceDate - internalOffset
        }
        publish(tc)
    }

    func locate(toSeconds s: Double) {
        locate(to: SMPTETimecode.from(totalSeconds: s, frameRate: frameRate))
    }

    // MARK: - External timecode input (SMPTE / Art-Net TC)

    func receiveSMPTE(_ tc: SMPTETimecode) {
        source = .smpte
        isRunning = true
        publish(tc)
    }

    func lostSMPTE() {
        if source == .smpte {
            source = .internal_
            isRunning = false
        }
    }

    // MARK: - Network Timecode input

    func receiveNetworkTimecode(_ tc: SMPTETimecode) {
        source = .network
        isRunning = true
        publish(tc)
    }

    // MARK: - Private

    private func startTicker() {
        let interval = 1.0 / frameRate.rawValue
        ticker = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.internalTick()
        }
        RunLoop.main.add(ticker!, forMode: .common)
    }

    private func internalTick() {
        let elapsed = Date().timeIntervalSinceReferenceDate - internalStart
        let tc = SMPTETimecode.from(totalSeconds: internalOffset + elapsed, frameRate: frameRate)
        publish(tc)
    }

    private func publish(_ tc: SMPTETimecode) {
        current = tc
        onTimecodeUpdate?(tc)
    }
}
