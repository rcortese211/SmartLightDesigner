import Foundation
import Vapor

// Manages all active sessions and connected clients.
// One Pi can hold multiple sessions; only sessions from a Pi in Player mode
// are joinable by Mac clients.

actor SessionServer {
    private var sessions:  [String: ManagedSession] = [:]      // sessionId → session
    private var clients:   [String: ConnectedClient] = [:]     // clientId → client
    private let engine:    ShowEngine

    init(engine: ShowEngine) {
        self.engine = engine
    }

    // MARK: - Client lifecycle

    func clientConnected(ws: WebSocket, piMode: PiRunMode) async -> String {
        let clientId = UUID().uuidString
        let client = ConnectedClient(ws: ws, clientId: clientId)
        clients[clientId] = client

        // Send welcome
        if let data = Envelope.make(.welcome, WelcomePayload(clientId: clientId, piMode: piMode)) {
            try? await ws.send(raw: data, opcode: .binary)
        }
        return clientId
    }

    func clientDisconnected(clientId: String) async {
        guard let client = clients.removeValue(forKey: clientId) else { return }
        // Remove from any session
        if let sid = client.sessionId,
           var session = sessions[sid] {
            session.clients.removeAll { $0.clientId == clientId }
            sessions[sid] = session
            await broadcastSessionState(sid)
        }
    }

    // MARK: - Message dispatch

    func handle(envelope: Envelope, from clientId: String) async {
        switch envelope.t {
        case .listSessions:
            await sendSessionsList(to: clientId)

        case .createSession:
            guard let p = decode(CreateSessionPayload.self, from: envelope.d) else { return }
            await createSession(name: p.sessionName, clientName: p.clientName,
                                role: p.role, clientId: clientId)

        case .joinRequest:
            guard let p = decode(JoinPayload.self, from: envelope.d) else { return }
            await joinSession(id: p.sessionId, clientName: p.clientName,
                              role: p.role, clientId: clientId)

        case .leaveRequest:
            await leaveSession(clientId: clientId)

        case .showUpdate:
            guard let data = envelope.d else { return }
            await handleShowUpdate(data: data, from: clientId)

        case .command:
            guard let p = decode(CommandPayload.self, from: envelope.d) else { return }
            await engine.handleCommand(p)
            await broadcastStatus()

        case .heartbeat:
            break  // Keep-alive, no response needed

        default: break
        }
    }

    // MARK: - Session management

    private func createSession(name: String, clientName: String,
                                role: SessionRole, clientId: String) async {
        let sessionId = UUID().uuidString
        let clientInfo = SessionClientInfo(clientId: clientId, name: clientName,
                                           role: role, connectedAt: Date().timeIntervalSinceReferenceDate)
        let session = ManagedSession(info: SessionInfo(sessionId: sessionId,
                                                       sessionName: name,
                                                       clients: [clientInfo]),
                                     showData: await engine.showData)
        sessions[sessionId] = session

        if var client = clients[clientId] {
            client.sessionId = sessionId
            clients[clientId] = client
        }

        await broadcastSessionState(sessionId)

        // Send current show state to the new client
        let showData = await engine.showData
        if !showData.isEmpty,
           let data = Envelope.make(.showState, RawData(data: showData)) {
            try? await clients[clientId]?.ws.send(raw: data, opcode: .binary)
        }
    }

    private func joinSession(id sessionId: String?, clientName: String,
                              role: SessionRole, clientId: String) async {
        // If no sessionId specified, join the first available session (or error)
        guard let sid = sessionId ?? sessions.keys.first,
              var session = sessions[sid] else {
            await sendError("Session not found", to: clientId)
            return
        }
        // Only one Pi per session (clients are Macs)
        let clientInfo = SessionClientInfo(clientId: clientId, name: clientName,
                                           role: role, connectedAt: Date().timeIntervalSinceReferenceDate)
        session.info.clients.append(clientInfo)
        sessions[sid] = session

        if var client = clients[clientId] {
            client.sessionId = sid
            clients[clientId] = client
        }

        await broadcastSessionState(sid)

        // Sync current show state to the new client
        let showData = session.showData
        if !showData.isEmpty,
           let data = Envelope.make(.showState, RawData(data: showData)) {
            try? await clients[clientId]?.ws.send(raw: data, opcode: .binary)
        }
    }

    private func leaveSession(clientId: String) async {
        guard let sid = clients[clientId]?.sessionId,
              var session = sessions[sid] else { return }
        session.info.clients.removeAll { $0.clientId == clientId }
        sessions[sid] = session
        if var client = clients[clientId] {
            client.sessionId = nil
            clients[clientId] = client
        }
        await broadcastSessionState(sid)
    }

    // MARK: - Show update with priority routing

    private func handleShowUpdate(data: Data, from clientId: String) async {
        guard let sid = clients[clientId]?.sessionId,
              var session = sessions[sid] else { return }

        let myPriority = session.info.clients.first(where: { $0.clientId == clientId })?.role.priority ?? 0
        let maxPriority = session.info.clients.map { $0.role.priority }.max() ?? 0

        // Only accept the update if this client has the highest priority
        guard myPriority >= maxPriority else { return }

        session.showData = data
        sessions[sid] = session
        await engine.applyShowData(data)

        // Broadcast to all other clients in this session
        let envelope = Envelope(t: .showState, id: clientId, d: data)
        if let envData = try? JSONEncoder().encode(envelope) {
            for info in session.info.clients where info.clientId != clientId {
                try? await clients[info.clientId]?.ws.send(raw: envData, opcode: .binary)
            }
        }
    }

    // MARK: - Broadcast helpers

    private func sendSessionsList(to clientId: String) async {
        let list = Array(sessions.values.map { $0.info })
        if let data = Envelope.make(.sessionsResponse, SessionsPayload(sessions: list)) {
            try? await clients[clientId]?.ws.send(raw: data, opcode: .binary)
        }
    }

    private func broadcastSessionState(_ sessionId: String) async {
        guard let session = sessions[sessionId] else { return }
        if let data = Envelope.make(.sessionState, session.info) {
            for info in session.info.clients {
                try? await clients[info.clientId]?.ws.send(raw: data, opcode: .binary)
            }
        }
    }

    func broadcastStatus() async {
        let status = await engine.currentStatus()
        guard let data = Envelope.make(.statusUpdate, status) else { return }
        for client in clients.values {
            try? await client.ws.send(raw: data, opcode: .binary)
        }
    }

    private func sendError(_ message: String, to clientId: String) async {
        if let data = Envelope.make(.sessionError, message) {
            try? await clients[clientId]?.ws.send(raw: data, opcode: .binary)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

// MARK: - Supporting types

private struct ManagedSession {
    var info: SessionInfo
    var showData: Data
}

private struct ConnectedClient {
    let ws: WebSocket
    let clientId: String
    var sessionId: String?
}

// Used to wrap raw Data in a Codable envelope
private struct RawData: Codable {
    var data: Data
}
