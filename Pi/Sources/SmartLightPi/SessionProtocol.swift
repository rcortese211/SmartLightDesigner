import Foundation

// Mirror of Sources/HueBase/Models/SessionProtocol.swift — keep in sync.

enum SessionRole: String, Codable, CaseIterable {
    case primary, control, editor

    var displayName: String {
        switch self {
        case .primary: "Primary"
        case .control: "Control"
        case .editor:  "Editor"
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

struct SessionClientInfo: Codable, Identifiable {
    var clientId: String
    var name: String
    var role: SessionRole
    var connectedAt: Double
    var id: String { clientId }
}

struct SessionInfo: Codable {
    var sessionId: String
    var sessionName: String
    var clients: [SessionClientInfo]
}

enum PiRunMode: String, Codable {
    case player, designer
}

enum MsgType: String, Codable {
    case welcome, sessionState, showState, statusUpdate, heartbeat, sessionError
    case joinRequest, leaveRequest, showUpdate, command
    case listSessions, createSession
    case sessionsResponse
}

struct Envelope: Codable {
    var t: MsgType
    var id: String?
    var d: Data?
}

extension Envelope {
    static func make<T: Encodable>(_ t: MsgType, _ payload: T, id: String? = nil) -> Data? {
        let d = try? JSONEncoder().encode(payload)
        return try? JSONEncoder().encode(Envelope(t: t, id: id, d: d))
    }
}

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
    var cmd: String
    var arg: String?
}
