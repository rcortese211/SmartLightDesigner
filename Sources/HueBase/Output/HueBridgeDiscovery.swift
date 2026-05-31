import Foundation
import Network

/// Discovers Philips Hue bridges via:
///   1. Local mDNS/Bonjour (_hue._tcp) — no internet required, preferred
///   2. N-UPnP cloud (discovery.meethue.com) — fallback when mDNS is unavailable
final class HueBridgeDiscovery {
    struct BridgeInfo: Identifiable, Hashable {
        let id: String
        let ip: String
        let name: String
    }

    var onDiscovered: (([BridgeInfo]) -> Void)?
    var onError: ((String) -> Void)?

    private var mdnsBrowser: NWBrowser?
    private var pendingConnections: [NWConnection] = []
    private var discovered: [String: BridgeInfo] = [:]   // keyed by IP to deduplicate
    private var discoveryWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "hue.discovery", qos: .userInitiated)

    func discover() {
        queue.async { [weak self] in
            self?.discovered.removeAll()
        }

        // Cancel any previous timeout
        discoveryWorkItem?.cancel()

        // Both methods run in parallel; after 8 s we report whatever was found
        let timeout = DispatchWorkItem { [weak self] in
            self?.queue.async {
                let results = Array(self?.discovered.values ?? [:].values)
                DispatchQueue.main.async { self?.onDiscovered?(results) }
            }
        }
        discoveryWorkItem = timeout
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 8, execute: timeout)

        discoverViaMDNS()
        discoverViaNUPnP()
    }

    func stopDiscovery() {
        mdnsBrowser?.cancel()
        mdnsBrowser = nil
        pendingConnections.forEach { $0.cancel() }
        pendingConnections.removeAll()
        discoveryWorkItem?.cancel()
        discoveryWorkItem = nil
    }

    // MARK: - mDNS / Bonjour

    private func discoverViaMDNS() {
        let params = NWParameters.tcp
        let browser = NWBrowser(for: .bonjour(type: "_hue._tcp", domain: nil), using: params)
        mdnsBrowser = browser

        browser.browseResultsChangedHandler = { [weak self] _, changes in
            for change in changes {
                if case .added(let result) = change {
                    self?.resolveEndpoint(result.endpoint)
                }
            }
        }

        browser.stateUpdateHandler = { [weak self] state in
            if case .failed(let err) = state {
                self?.onError?("mDNS browse error: \(err.localizedDescription)")
            }
        }

        browser.start(queue: queue)
    }

    private func resolveEndpoint(_ endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        queue.async { self.pendingConnections.append(connection) }

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                defer { connection.cancel() }
                guard let remote = connection.currentPath?.remoteEndpoint,
                      case .hostPort(let host, _) = remote else { return }
                let ip = Self.hostString(host)
                guard !ip.isEmpty else { return }

                let name: String
                if case .service(let svcName, _, _, _) = endpoint { name = svcName }
                else { name = "Hue Bridge" }

                let bridge = BridgeInfo(id: ip, ip: ip,
                                        name: name.isEmpty ? "Hue Bridge (\(ip))" : name)
                self?.addBridge(bridge)

            case .failed:
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: queue)

        // Connection-level timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 4) { connection.cancel() }
    }

    private static func hostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let a): return "\(a)"
        case .ipv6:        return ""   // Hue API is IPv4-only; link-local IPv6 won't work in URLs
        case .name(let h, _): return h
        @unknown default: return ""
        }
    }

    // MARK: - N-UPnP (cloud-assisted)

    private func discoverViaNUPnP() {
        guard let url = URL(string: "https://discovery.meethue.com") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error {
                self?.onError?("N-UPnP: \(error.localizedDescription)")
                return
            }
            // The response includes non-string fields (e.g. "port": 443), so decode as [String: Any]
            guard let data,
                  let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else {
                self?.onError?("N-UPnP: unexpected response from discovery server")
                return
            }
            for dict in list {
                guard let ip = dict["internalipaddress"] as? String else { continue }
                let id = (dict["id"] as? String) ?? ip
                let bridge = BridgeInfo(id: id, ip: ip, name: "Hue Bridge (\(ip))")
                self?.addBridge(bridge)
            }
        }.resume()
    }

    // MARK: - Helpers

    private func addBridge(_ bridge: BridgeInfo) {
        queue.async { [weak self] in
            guard let self else { return }
            let isNew = self.discovered[bridge.ip] == nil
            self.discovered[bridge.ip] = bridge
            if isNew {
                let results = Array(self.discovered.values)
                DispatchQueue.main.async { self.onDiscovered?(results) }
            }
        }
    }

    // MARK: - Pairing

    func pair(bridgeIP: String, appName: String = "HueBase",
              completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "http://\(bridgeIP)/api") else {
            DispatchQueue.main.async {
                completion(.failure(HueError.bridgeError(
                    "'\(bridgeIP)' is not a valid IPv4 address. Re-enter or use Discover."
                )))
            }
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["devicetype": appName])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data,
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = array.first
            else {
                DispatchQueue.main.async { completion(.failure(HueError.unexpectedResponse)) }
                return
            }
            if let success = first["success"] as? [String: Any],
               let username = success["username"] as? String {
                DispatchQueue.main.async { completion(.success(username)) }
            } else if let errorBlock = first["error"] as? [String: Any],
                      let desc = errorBlock["description"] as? String {
                DispatchQueue.main.async { completion(.failure(HueError.bridgeError(desc))) }
            } else {
                DispatchQueue.main.async { completion(.failure(HueError.unexpectedResponse)) }
            }
        }.resume()
    }

    func fetchLights(bridgeIP: String, username: String,
                     completion: @escaping ([String: String]) -> Void) {
        guard let url = URL(string: "http://\(bridgeIP)/api/\(username)/lights") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { DispatchQueue.main.async { completion([:]) }; return }
            let names = dict.compactMapValues { ($0 as? [String: Any])?["name"] as? String }
            DispatchQueue.main.async { completion(names) }
        }.resume()
    }

    enum HueError: LocalizedError {
        case unexpectedResponse
        case bridgeError(String)
        var errorDescription: String? {
            switch self {
            case .unexpectedResponse: return "Unexpected response from bridge"
            case .bridgeError(let d): return d
            }
        }
    }
}
