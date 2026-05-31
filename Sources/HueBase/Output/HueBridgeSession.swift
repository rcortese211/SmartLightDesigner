import Foundation

/// URLSessionDelegate that trusts self-signed certificates from Philips Hue bridges.
/// Only bypasses cert validation for RFC-1918 local network addresses.
final class HueBridgeTrustDelegate: NSObject, URLSessionDelegate {

    static let shared = HueBridgeTrustDelegate()

    static func makeSession(requestTimeout: TimeInterval = 10) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.waitsForConnectivity = false
        return URLSession(configuration: config, delegate: shared, delegateQueue: nil)
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              isLocalAddress(challenge.protectionSpace.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private func isLocalAddress(_ host: String) -> Bool {
        if host == "localhost" || host == "127.0.0.1" { return true }
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") { return true }
        // 172.16.0.0 – 172.31.255.255
        if host.hasPrefix("172.") {
            let parts = host.split(separator: ".").compactMap { Int($0) }
            if parts.count >= 2, parts[1] >= 16, parts[1] <= 31 { return true }
        }
        return false
    }
}
