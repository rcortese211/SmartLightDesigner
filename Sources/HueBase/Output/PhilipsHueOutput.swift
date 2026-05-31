import Foundation

/// DMX output driver that translates RGB fixture channels into Philips Hue
/// light commands via the local bridge HTTP API (v1).
///
/// Rate-limiting: The Hue bridge accepts ~10-20 PUT requests/sec per light.
/// We coalesce updates and send at `config.updateRateHz` (default 20 Hz).
final class PhilipsHueOutput: DMXOutputDriver {
    var isEnabled: Bool
    var config: HueConfiguration

    private let session: URLSession
    private var pendingUpdates: [String: LightState] = [:]   // lightId → desired state
    private var sendTimer: Timer?

    struct LightState {
        var on: Bool
        var bri: Int          // 1-254
        var xy: (Double, Double)
    }

    init(config: HueConfiguration) {
        self.config = config
        self.isEnabled = config.enabled
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 0.4
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
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

        for (lightId, state) in updates {
            var body: [String: Any] = ["on": state.on]
            if state.on {
                body["bri"] = state.bri
                body["xy"]  = [state.xy.0, state.xy.1]
                body["transitiontime"] = 1   // 100ms smooth transition
            }
            putLightState(lightId: lightId, body: body)
        }
    }

    private func putLightState(lightId: String, body: [String: Any]) {
        let urlStr = "http://\(config.bridgeIP)/api/\(config.username)/lights/\(lightId)/state"
        guard let url = URL(string: urlStr),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        session.dataTask(with: req).resume()
    }

    // MARK: - sRGB → CIE 1931 xy (Philips wide-gamut matrix)

    private func sRGBtoXY(r: Double, g: Double, b: Double) -> (Double, Double) {
        // Gamma expand
        let rr = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92
        let gg = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92
        let bb = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4) : b / 12.92

        // Wide-gamut Hue D65 matrix (Philips recommendation)
        let X = rr * 0.664511 + gg * 0.154324 + bb * 0.162028
        let Y = rr * 0.283881 + gg * 0.668433 + bb * 0.047685
        let Z = rr * 0.000088 + gg * 0.072310 + bb * 0.986039

        let sum = X + Y + Z
        guard sum > 0 else { return (0.3127, 0.3290) }  // D65 white point
        return (X / sum, Y / sum)
    }
}
