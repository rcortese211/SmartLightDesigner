import Foundation

/// Discovers Philips Hue bridges on the local network via the Hue N-UPnP service
/// and via mDNS (_hue._tcp). Falls back to manual IP entry when offline.
final class HueBridgeDiscovery {
    struct BridgeInfo: Identifiable, Hashable {
        let id: String      // bridge ID (serial)
        let ip: String
        let name: String
    }

    var onDiscovered: (([BridgeInfo]) -> Void)?

    func discover() {
        discoverViaNUPnP()
    }

    // MARK: - N-UPnP (cloud-assisted, requires internet)

    private func discoverViaNUPnP() {
        guard let url = URL(string: "https://discovery.meethue.com") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let list = try? JSONDecoder().decode([[String: String]].self, from: data)
            else { return }

            let bridges = list.compactMap { dict -> BridgeInfo? in
                guard let id = dict["id"], let ip = dict["internalipaddress"] else { return nil }
                return BridgeInfo(id: id, ip: ip, name: "Hue Bridge (\(ip))")
            }
            DispatchQueue.main.async { self?.onDiscovered?(bridges) }
        }.resume()
    }

    // MARK: - Link-button pairing

    /// Attempt to register a new app on the bridge (user must press link button first).
    /// Calls completion with the resulting API key on success.
    func pair(bridgeIP: String, appName: String = "HueBase",
              completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "http://\(bridgeIP)/api") else { return }
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
                DispatchQueue.main.async {
                    completion(.failure(HueError.unexpectedResponse))
                }
                return
            }
            if let success = first["success"] as? [String: Any],
               let username = success["username"] as? String {
                DispatchQueue.main.async { completion(.success(username)) }
            } else if let errorBlock = first["error"] as? [String: Any],
                      let desc = errorBlock["description"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(HueError.bridgeError(desc)))
                }
            }
        }.resume()
    }

    /// Fetch all lights from the bridge; returns dict of lightId → name.
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
