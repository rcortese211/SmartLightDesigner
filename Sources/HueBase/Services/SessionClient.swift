import Foundation
import Observation

// macOS-side WebSocket client that connects to a Pi running in Player mode.

@Observable
final class SessionClient {

    // MARK: - Connection state

    enum State: Equatable {
        case disconnected
        case connecting
        case connectedIdle(clientId: String, piMode: PiRunMode)
        case inSession(session: SessionInfo, clientId: String, role: SessionRole, piMode: PiRunMode)
        case error(String)

        var isConnected: Bool {
            switch self { case .connectedIdle, .inSession: true; default: false }
        }
        var session: SessionInfo? {
            if case .inSession(let s, _, _, _) = self { return s }; return nil
        }
        var clientId: String? {
            switch self {
            case .connectedIdle(let id, _): return id
            case .inSession(_, let id, _, _): return id
            default: return nil
            }
        }
        var role: SessionRole? {
            if case .inSession(_, _, let r, _) = self { return r }; return nil
        }
    }

    var state: State = .disconnected
    var availableSessions: [SessionInfo] = []
    var piStatus: PiStatusPayload? = nil

    // Callback: Pi pushed a full show JSON to sync into AppState
    var onShowStateReceived: ((Data) -> Void)?
    // Callback: session roster changed
    var onSessionUpdated: ((SessionInfo) -> Void)?

    private var wsTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var piAddress = ""

    deinit { disconnect() }

    // MARK: - Lifecycle

    func connect(to address: String, port: Int = 8080) async {
        piAddress = address
        guard let url = URL(string: "ws://\(address):\(port)/session") else {
            await setState(.error("Invalid Pi address: \(address)"))
            return
        }
        await setState(.connecting)
        let task = URLSession.shared.webSocketTask(with: url)
        wsTask = task
        task.resume()
        await receiveLoop()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        Task { await setState(.disconnected) }
    }

    // MARK: - Session actions

    func listSessions() async {
        await send(.make(.listSessions, EmptyP()))
    }

    func joinSession(id sessionId: String?, clientName: String, role: SessionRole) async {
        let p = JoinPayload(clientName: clientName, role: role, sessionId: sessionId)
        await send(.make(.joinRequest, p))
    }

    func createSession(sessionName: String, clientName: String, role: SessionRole) async {
        let p = CreateSessionPayload(sessionName: sessionName, clientName: clientName, role: role)
        await send(.make(.createSession, p))
    }

    func leaveSession() async {
        await send(.make(.leaveRequest, EmptyP()))
        if case .inSession(_, let id, _, let mode) = state {
            await setState(.connectedIdle(clientId: id, piMode: mode))
        }
    }

    func sendShowUpdate(_ showData: Data) async {
        guard state.isConnected else { return }
        let env = Envelope(t: .showUpdate, id: state.clientId, d: showData)
        if let d = try? JSONEncoder().encode(env) { try? await wsTask?.send(.data(d)) }
    }

    func sendCommand(_ cmd: String, arg: String? = nil) async {
        await send(.make(.command, CommandPayload(cmd: cmd, arg: arg), id: state.clientId))
    }

    // MARK: - Private

    @MainActor
    private func setState(_ newState: State) {
        state = newState
    }

    private func send(_ data: Data?) async {
        guard let data else { return }
        try? await wsTask?.send(.data(data))
    }

    private func receiveLoop() async {
        guard let task = wsTask else { return }
        startHeartbeat()
        while true {
            do {
                let msg = try await task.receive()
                let data: Data?
                switch msg {
                case .data(let d):   data = d
                case .string(let s): data = s.data(using: .utf8)
                @unknown default:    data = nil
                }
                if let d = data { await handle(d) }
            } catch {
                await setState(.error("Connection lost: \(error.localizedDescription)"))
                break
            }
        }
    }

    @MainActor
    private func handle(_ data: Data) {
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        switch env.t {
        case .welcome:
            guard let p = decode(WelcomePayload.self, from: env.d) else { return }
            state = .connectedIdle(clientId: p.clientId, piMode: p.piMode)
            Task { await listSessions() }

        case .sessionsResponse:
            if let p = decode(SessionsPayload.self, from: env.d) { availableSessions = p.sessions }

        case .sessionState:
            guard let session = decode(SessionInfo.self, from: env.d) else { return }
            onSessionUpdated?(session)
            // Determine our role from the session roster
            if let myId = state.clientId,
               let me = session.clients.first(where: { $0.clientId == myId }) {
                let mode: PiRunMode
                if case .inSession(_, _, _, let m) = state { mode = m }
                else if case .connectedIdle(_, let m) = state { mode = m }
                else { mode = .player }
                state = .inSession(session: session, clientId: myId, role: me.role, piMode: mode)
            }

        case .showState:
            if let d = env.d { onShowStateReceived?(d) }

        case .statusUpdate:
            if let p = decode(PiStatusPayload.self, from: env.d) { piStatus = p }

        case .sessionError:
            let msg = env.d.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            state = .error(msg)

        default: break
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func startHeartbeat() {
        DispatchQueue.main.async {
            self.pingTimer?.invalidate()
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
                Task { await self?.send(.make(.heartbeat, EmptyP())) }
            }
        }
    }
}

private struct EmptyP: Codable {}
