import Foundation
import Network

final class OSCServer {
    private var listener: NWListener?
    private var handlers: [String: (OSCMessage) -> Void] = [:]
    private var sendConnection: NWConnection?

    var listenPort: UInt16 = 8000
    var isRunning: Bool = false

    func start(port: UInt16 = 8000) {
        listenPort = port
        let params = NWParameters.udp
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        listener = try? NWListener(using: params, on: nwPort)
        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global(qos: .utility))
            self?.receive(on: conn)
        }
        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.isRunning = (state == .ready)
            }
        }
        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    func addHandler(address: String, handler: @escaping (OSCMessage) -> Void) {
        handlers[address] = handler
    }

    func send(address: String, arguments: [OSCArgument] = [], toIP: String, port: UInt16) {
        if sendConnection == nil {
            let host = NWEndpoint.Host(toIP)
            let p = NWEndpoint.Port(rawValue: port) ?? 8001
            sendConnection = NWConnection(host: host, endpoint: .hostPort(host: host, port: p), using: .udp)
            sendConnection?.start(queue: .global(qos: .utility))
        }
        let packet = OSCMessage.build(address: address, arguments: arguments)
        sendConnection?.send(content: packet, completion: .idempotent)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            if let data, let msg = OSCMessage.parse(data) {
                DispatchQueue.main.async {
                    // Exact match first, then prefix pattern match
                    if let handler = self?.handlers[msg.address] {
                        handler(msg)
                    } else {
                        self?.handlers.forEach { pattern, handler in
                            if msg.address.hasPrefix(pattern) { handler(msg) }
                        }
                    }
                }
            }
            if error == nil {
                self?.receive(on: connection)
            }
        }
    }
}
