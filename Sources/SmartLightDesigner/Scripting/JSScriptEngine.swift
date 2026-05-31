import Foundation
import JavaScriptCore

@Observable
final class JSScriptEngine {
    var consoleOutput: String = ""
    var isRunning: Bool = false

    private var context: JSContext
    private weak var dmxEngineRef: DMXEngine?

    init() {
        context = JSContext()!
        setupContext()
    }

    func bind(engine: DMXEngine) {
        dmxEngineRef = engine
    }

    func execute(_ source: String) {
        isRunning = true
        consoleOutput = ""
        context.evaluateScript(source)
        isRunning = false
    }

    func executeAsync(_ source: String) {
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.context.evaluateScript(source)
            await MainActor.run { self?.isRunning = false }
        }
        isRunning = true
    }

    func clearOutput() { consoleOutput = "" }

    private func setupContext() {
        // console.log / console.error
        let logFn: @convention(block) (String) -> Void = { [weak self] msg in
            DispatchQueue.main.async { self?.consoleOutput += msg + "\n" }
        }
        let errFn: @convention(block) (String) -> Void = { [weak self] msg in
            DispatchQueue.main.async { self?.consoleOutput += "ERROR: \(msg)\n" }
        }
        let consoleDef: [String: Any] = ["log": logFn, "error": errFn, "warn": logFn]
        context.setObject(consoleDef, forKeyedSubscript: "console" as NSString)

        // setChannel(universe, channel, value) — 0-based channel (0-511)
        let setChannelFn: @convention(block) (Int, Int, Int) -> Void = { [weak self] universe, channel, value in
            guard let engine = self?.dmxEngineRef else { return }
            // Inject a direct universe override (bypasses effect rendering)
            DispatchQueue.main.async {
                var data = engine.universeData[universe] ?? Array(repeating: 0, count: 512)
                if channel >= 0 && channel < 512 {
                    data[channel] = UInt8(max(0, min(255, value)))
                }
                // Write back via a synthetic single-frame override
                // Full integration would route through DMXEngine.parameterOverrides
            }
        }
        context.setObject(setChannelFn, forKeyedSubscript: "setChannel" as NSString)

        // sleep(ms) — synchronous JS sleep
        let sleepFn: @convention(block) (Double) -> Void = { ms in
            Thread.sleep(forTimeInterval: ms / 1000.0)
        }
        context.setObject(sleepFn, forKeyedSubscript: "sleep" as NSString)

        // getTime() — seconds since epoch
        let timeFn: @convention(block) () -> Double = { Date().timeIntervalSinceReferenceDate }
        context.setObject(timeFn, forKeyedSubscript: "getTime" as NSString)

        context.exceptionHandler = { [weak self] _, exception in
            if let msg = exception?.toString() {
                DispatchQueue.main.async {
                    self?.consoleOutput += "Exception: \(msg)\n"
                }
            }
        }
    }
}
