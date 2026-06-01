import Vapor
import Foundation

// Entry point: `SmartLightPi [--player|--designer] [--port N]`
// Defaults to Player mode on port 8080.

var env = try Environment.detect()
let app = try Application(.detect(arguments: ["vapor"] + CommandLine.arguments.dropFirst()))

// Parse mode & port from command-line
let args = Array(CommandLine.arguments.dropFirst())
var mode = PiMode.from(args: args)
var port = 8080
if let pi = args.firstIndex(of: "--port"), pi + 1 < args.count {
    port = Int(args[pi + 1]) ?? 8080
}

// Override Vapor's environment detection with our port
app.http.server.configuration.port = port

let config = PiConfig.load()
let engine = ShowEngine(config: config)
let server = SessionServer(engine: engine)

// Register routes
try registerRoutes(app: app, server: server, engine: engine, mode: mode)

// Status broadcast timer (every 2s)
let loop = app.eventLoopGroup.next()
loop.scheduleRepeatedTask(initialDelay: .seconds(2), delay: .seconds(2)) { _ in
    Task { await server.broadcastStatus() }
}

print("""

SmartLight Pi v1.0
Mode: \(mode.rawValue.uppercased())
URL:  http://0.0.0.0:\(port)
\(mode == .player ? "Session WS: ws://0.0.0.0:\(port)/session" : "No session WS in designer mode")

""")

defer { app.shutdown() }
try app.run()
