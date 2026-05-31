import AVFoundation
import CoreAudio
import Observation

@Observable
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var fileURL: URL?

    private(set) var isLoaded = false
    private(set) var fileDuration: Double = 0
    private(set) var fileName: String = ""
    private(set) var waveformSamples: [Float] = []   // RMS per bucket, left channel

    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode,
                       format: engine.mainMixerNode.outputFormat(forBus: 0))
    }

    // MARK: - File loading

    func loadFile(url: URL) throws {
        playerNode.stop()
        let file = try AVAudioFile(forReading: url)
        let fmt = file.processingFormat
        fileDuration = Double(file.length) / fmt.sampleRate
        fileName = url.lastPathComponent
        fileURL = url
        engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)
        audioFile = file
        isLoaded = true
        waveformSamples = []
        let targetBuckets = min(32768, max(8192, Int(fileDuration * 100)))
        extractWaveform(url: url, totalFrames: file.length, format: fmt, targetBuckets: targetBuckets)
    }

    func unload() {
        playerNode.stop()
        audioFile = nil
        fileURL = nil
        isLoaded = false
        fileDuration = 0
        fileName = ""
        waveformSamples = []
    }

    // MARK: - Waveform extraction (background)

    private func extractWaveform(url: URL, totalFrames: AVAudioFramePosition,
                                  format: AVAudioFormat, targetBuckets: Int = 1024) {
        let framesPerBucket = max(1, Int(totalFrames) / targetBuckets)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat,
                      frameCapacity: AVAudioFrameCount(framesPerBucket))
            else { return }

            var buckets: [Float] = []
            buckets.reserveCapacity(targetBuckets)

            while file.framePosition < totalFrames {
                buffer.frameLength = 0
                guard (try? file.read(into: buffer)) != nil,
                      buffer.frameLength > 0,
                      let ch = buffer.floatChannelData else { break }
                let n = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<n { let s = ch[0][i]; sum += s * s }
                buckets.append(sqrt(sum / Float(n)))
            }

            DispatchQueue.main.async { [weak self] in
                self?.waveformSamples = buckets
            }
        }
    }

    // MARK: - Transport

    func play(from startTime: Double = 0) {
        guard let audioFile, isLoaded else { return }
        playerNode.stop()
        if !engine.isRunning { try? engine.start() }
        let sr = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, startTime) * sr)
        let remaining = AVAudioFrameCount(max(0, audioFile.length - startFrame))
        guard remaining > 0 else { return }
        playerNode.scheduleSegment(audioFile, startingFrame: startFrame,
                                   frameCount: remaining, at: nil)
        playerNode.play()
    }

    func pause() { playerNode.pause() }
    func stop() { playerNode.stop() }

    func setVolume(_ v: Double) { playerNode.volume = Float(max(0, min(1, v))) }

    // MARK: - Device selection

    func setOutputDevice(uid: String) {
        guard !uid.isEmpty,
              let au = engine.outputNode.audioUnit,
              let deviceID = deviceIDForUID(uid) else { return }
        var id = deviceID
        AudioUnitSetProperty(au, kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global, 0, &id,
                             UInt32(MemoryLayout<AudioDeviceID>.size))
    }

    // MARK: - Device enumeration (static)

    static func availableOutputDevices() -> [(name: String, uid: String)] {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize) == noErr,
              dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize, &ids) == noErr
        else { return [] }

        var results: [(name: String, uid: String)] = []
        for id in ids {
            var outAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)
            var outSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &outAddr, 0, nil, &outSize) == noErr,
                  outSize >= MemoryLayout<UInt32>.size else { continue }
            let rawBuf = UnsafeMutableRawPointer.allocate(byteCount: Int(outSize), alignment: 8)
            defer { rawBuf.deallocate() }
            var readSize = outSize
            guard AudioObjectGetPropertyData(id, &outAddr, 0, nil, &readSize, rawBuf) == noErr else { continue }
            let numBuffers = rawBuf.load(as: UInt32.self)
            guard numBuffers > 0 else { continue }

            var name: CFString = "" as CFString
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &name)

            var uid: CFString = "" as CFString
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uidSize, &uid)

            let nameStr = name as String
            let uidStr = uid as String
            if !uidStr.isEmpty {
                results.append((name: nameStr.isEmpty ? "Unknown Device" : nameStr, uid: uidStr))
            }
        }
        return results
    }

    // MARK: - Private helpers

    private func deviceIDForUID(_ uid: String) -> AudioDeviceID? {
        var cfUID = uid as CFString
        var deviceID: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
        var translation = AudioValueTranslation(
            mInputData: &cfUID,
            mInputDataSize: UInt32(MemoryLayout<CFString>.size),
            mOutputData: &deviceID,
            mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size))
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &size, &translation)
        return deviceID != AudioDeviceID(kAudioObjectUnknown) ? deviceID : nil
    }
}
