import Foundation

// Shared session wire protocol — identical copy lives in Pi/Sources/SmartLightPi/SessionProtocol.swift

// MARK: - Role

enum SessionRole: String, Codable, CaseIterable, Identifiable {
    case primary, control, editor
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary: "Primary"
        case .control: "Control"
        case .editor:  "Editor"
        }
    }

    var roleDescription: String {
        switch self {
        case .primary:
            "Full authority — Pi always reflects your show state. Overrides all other roles."
        case .control:
            "Run the show via the Pi. Changes apply immediately unless a Primary is active."
        case .editor:
            "Design at lower priority. Changes apply only when no Primary or Control is active."
        }
    }

    var priority: Int {
        switch self {
        case .primary: 3
        case .control: 2
        case .editor:  1
        }
    }
}

// MARK: - Session model

struct SessionClientInfo: Codable, Identifiable, Equatable {
    var clientId: String
    var name: String
    var role: SessionRole
    var connectedAt: Double
    var id: String { clientId }
}

struct SessionInfo: Codable, Identifiable, Equatable {
    var sessionId: String
    var sessionName: String
    var clients: [SessionClientInfo]
    var id: String { sessionId }
}

enum PiRunMode: String, Codable, Equatable {
    case player, designer
}

// MARK: - Wire envelope

enum MsgType: String, Codable {
    // Pi → Mac
    case welcome, sessionState, showState, statusUpdate, heartbeat, sessionError
    // Mac → Pi
    case joinRequest, leaveRequest, showUpdate, command
    case listSessions, createSession
    // Response
    case sessionsResponse
}

struct Envelope: Codable {
    var t: MsgType
    var id: String?     // sender clientId
    var d: Data?        // JSON-encoded payload
}

extension Envelope {
    static func make<T: Encodable>(_ t: MsgType, _ payload: T, id: String? = nil) -> Data? {
        let d = try? JSONEncoder().encode(payload)
        return try? JSONEncoder().encode(Envelope(t: t, id: id, d: d))
    }
}

// MARK: - Typed payloads

struct WelcomePayload: Codable {
    var clientId: String
    var piMode: PiRunMode
}

struct JoinPayload: Codable {
    var clientName: String
    var role: SessionRole
    var sessionId: String?
}

struct CreateSessionPayload: Codable {
    var sessionName: String
    var clientName: String
    var role: SessionRole
}

struct SessionsPayload: Codable {
    var sessions: [SessionInfo]
}

struct PiStatusPayload: Codable {
    var fps: Double
    var outputEnabled: Bool
    var timelinePosition: Double?
    var isPlaying: Bool
    var timecodeSource: String
    var activeCueName: String?
    var uptime: Double
}

struct CommandPayload: Codable {
    var cmd: String  // "output.on"|"output.off"|"tl.play"|"tl.pause"|"tl.stop"|"cue.go"|"cue.back"|"tc.source"
    var arg: String?
}
