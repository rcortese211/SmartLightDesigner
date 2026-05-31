import Foundation

/// DMX output driver that translates RGB fixture channels into Philips Hue
/// light commands via the local bridge HTTP API (v1).
///
/// Rate-limiting: HTTPS round-trip overhead limits sustainable throughput to
/// ~10 updates/sec per light. Requests are coalesced, deduplicated against the
/// last-sent state, and any in-flight task for a light is cancelled before a
/// new one is issued to prevent out-of-order arrival causing jumpiness.
final class PhilipsHueOutput: DMXOutputDriver {
    var isEnabled: Bool
    var config: HueConfiguration

    private let session: URLSession
    private var pendingUpdates: [String: LightState] = [:]
    private var lastSentState:  [String: LightState] = [:]
    private var inFlightTasks:  [String: URLSessionDataTask] = [:]
    private var sendTimer: Timer?

    struct LightState: Equatable {
        var on: Bool
        var bri: Int
        var xy: (Double, Double)

        static func == (lhs: LightState, rhs: LightState) -> Bool {
            guard lhs.on == rhs.on else { return false }
            guard lhs.on else { return true }   // both off — equal
            return abs(lhs.bri - rhs.bri) <= 1
                && abs(lhs.xy.0 - rhs.xy.0) < 0.005
                && abs(lhs.xy.1 - rhs.xy.1) < 0.005
        }
    }

    init(config: HueConfiguration) {
        self.config = config
        self.isEnabled = config.enabled
        self.session = HueBridgeTrustDelegate.makeSession(requestTimeout: 0.4)
    }

    func start() {
        let interval = 1.0 / max(1, config.updateRateHz)
        sendTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.flushPendingUpdates()
        }
        RunLoop.main.add(sendTimer!, forMode: .common)
    }

    func stop() {
        sendTimer?.invalidate()
        sendTimer = nil
        pendingUpdates.removeAll()
        inFlightTasks.values.forEach { $0.cancel() }
        inFlightTasks.removeAll()
    }

    func send(universe: Int, values: [UInt8]) {
        guard isEnabled else { return }

        for mapping in config.lightMappings where mapping.universe == universe {
            let si = mapping.startAddress - 1
            guard si + 2 < values.count else { continue }

            let r = Double(values[si])     / 255.0
            let g = Double(values[si + 1]) / 255.0
            let b = Double(values[si + 2]) / 255.0
            let brightness = max(r, g, b)

            if brightness < 0.004 {
                pendingUpdates[mapping.lightId] = LightState(on: false, bri: 1, xy: (0.3127, 0.3290))
            } else {
                let (x, y) = sRGBtoXY(r: r / brightness, g: g / brightness, b: b / brightness)
                pendingUpdates[mapping.lightId] = LightState(
                    on:  true,
                    bri: max(1, min(254, Int(brightness * 254))),
                    xy:  (x, y)
                )
            }
        }
    }

    // MARK: - Private

    private func flushPendingUpdates() {
        guard !config.bridgeIP.isEmpty, !config.username.isEmpty else { return }
        let updates = pendingUpdates
        pendingUpdates.removeAll()

        // transitiontime units = 100ms; match the send interval so the bridge
        // interpolates smoothly from one frame to the next without overshooting
        let tt = max(0, Int((1.0 / config.updateRateHz) * 10))

        for (lightId, state) in updates {
            // Skip if the bridge is already showing this state
            if lastSentState[lightId] == state { continue }

            var body: [String: Any] = ["on": state.on]
            if state.on {
                body["bri"]            = state.bri
                body["xy"]             = [state.xy.0, state.xy.1]
                body["transitiontime"] = tt
            }
            lastSentState[lightId] = state
            putLightState(lightId: lightId, body: body)
        }
    }

    private func putLightState(lightId: String, body: [String: Any]) {
        let urlStr = "https://\(config.bridgeIP)/api/\(config.username)/lights/\(lightId)/state"
        guard let url = URL(string: urlStr),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Cancel any previous in-flight task for this light to prevent out-of-order arrival
        inFlightTasks[lightId]?.cancel()
        let task = session.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.async { self?.inFlightTasks.removeValue(forKey: lightId) }
        }
        inFlightTasks[lightId] = task
        task.resume()
    }

    // MARK: - sRGB → CIE 1931 xy (Philips wide-gamut matrix)

    private func sRGBtoXY(r: Double, g: Double, b: Double) -> (Double, Double) {
        let rr = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92
        let gg = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92
        let bb = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4) : b / 12.92

        let X = rr * 0.664511 + gg * 0.154324 + bb * 0.162028
        let Y = rr * 0.283881 + gg * 0.668433 + bb * 0.047685
        let Z = rr * 0.000088 + gg * 0.072310 + bb * 0.986039

        let sum = X + Y + Z
        guard sum > 0 else { return (0.3127, 0.3290) }
        return (X / sum, Y / sum)
    }
}
