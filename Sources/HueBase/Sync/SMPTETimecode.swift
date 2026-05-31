import Foundation

struct SMPTETimecode: Equatable, Hashable, CustomStringConvertible {
    var hours:   Int
    var minutes: Int
    var seconds: Int
    var frames:  Int
    var frameRate: TimecodeFrameRate

    static let zero = SMPTETimecode(hours: 0, minutes: 0, seconds: 0, frames: 0, frameRate: .fps25)

    var totalSeconds: Double {
        Double(hours * 3600 + minutes * 60 + seconds) + Double(frames) / frameRate.rawValue
    }

    var totalFrames: Int {
        Int(totalSeconds * frameRate.rawValue)
    }

    static func from(totalSeconds: Double, frameRate: TimecodeFrameRate) -> SMPTETimecode {
        let fps  = frameRate.rawValue
        let tf   = max(0, Int(totalSeconds * fps))
        let fpsi = Int(fps)
        return SMPTETimecode(
            hours:     tf / (fpsi * 3600),
            minutes:  (tf % (fpsi * 3600)) / (fpsi * 60),
            seconds:  (tf % (fpsi * 60))   /  fpsi,
            frames:    tf %  fpsi,
            frameRate: frameRate
        )
    }

    var description: String {
        String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    // Parse from Art-Net ArtTimeCode fields
    static func fromArtNet(hours: UInt8, minutes: UInt8, seconds: UInt8,
                           frames: UInt8, type: UInt8) -> SMPTETimecode {
        let rate: TimecodeFrameRate
        switch type {
        case 0: rate = .fps24
        case 1: rate = .fps25
        case 2: rate = .fps2997
        default: rate = .fps30
        }
        return SMPTETimecode(hours: Int(hours), minutes: Int(minutes),
                             seconds: Int(seconds), frames: Int(frames), frameRate: rate)
    }

    // Pack into 8-byte HueBase Network TC packet body
    func toNetworkPacket() -> [UInt8] {
        let rateCode: UInt8
        switch frameRate {
        case .fps24:   rateCode = 0
        case .fps25:   rateCode = 1
        case .fps2997: rateCode = 2
        case .fps30:   rateCode = 3
        }
        return [
            UInt8(hours), UInt8(minutes), UInt8(seconds), UInt8(frames),
            rateCode, 0, 0, 0   // rate, flags, reserved x2
        ]
    }

    static func fromNetworkPacket(_ bytes: [UInt8]) -> SMPTETimecode? {
        guard bytes.count >= 6 else { return nil }
        let rate: TimecodeFrameRate
        switch bytes[4] {
        case 0: rate = .fps24
        case 1: rate = .fps25
        case 2: rate = .fps2997
        default: rate = .fps30
        }
        return SMPTETimecode(hours: Int(bytes[0]), minutes: Int(bytes[1]),
                             seconds: Int(bytes[2]), frames: Int(bytes[3]), frameRate: rate)
    }
}
