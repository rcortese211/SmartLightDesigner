import Vapor

func registerRoutes(app: Application, server: SessionServer, engine: ShowEngine, mode: PiMode) throws {

    // MARK: - Session WebSocket (only in Player mode)
    // In Designer mode sessions are not available — the Pi is a standalone designer.

    if mode == .player {
        app.webSocket("session") { req, ws in
            let clientId = await server.clientConnected(ws: ws, piMode: .player)

            ws.onBinary { ws, buffer in
                guard let data = Data(buffer: buffer),
                      let env = try? JSONDecoder().decode(Envelope.self, from: data)
                else { return }
                await server.handle(envelope: env, from: clientId)
            }

            ws.onText { ws, text in
                guard let data = text.data(using: .utf8),
                      let env = try? JSONDecoder().decode(Envelope.self, from: data)
                else { return }
                await server.handle(envelope: env, from: clientId)
            }

            ws.onClose.whenComplete { _ in
                Task { await server.clientDisconnected(clientId: clientId) }
            }
        }

        // Status API for polling clients
        app.get("api", "status") { req async -> Response in
            let status = await engine.currentStatus()
            let body = try JSONEncoder().encode(status)
            return Response(status: .ok,
                            headers: HTTPHeaders([("Content-Type", "application/json")]),
                            body: .init(data: body))
        }

        // Command API (REST fallback if WS not available)
        app.post("api", "command") { req async throws -> Response in
            let cmd = try req.content.decode(CommandPayload.self)
            await engine.handleCommand(cmd)
            return Response(status: .noContent)
        }

        // Player UI
        app.get { req in
            req.eventLoop.future(Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/html; charset=utf-8")]),
                body: .init(string: PlayerUI.html(port: app.http.server.configuration.port))
            ))
        }

    } else {
        // MARK: - Designer mode

        // Full show API
        app.get("api", "show") { req async -> Response in
            let data = await engine.showData
            return Response(status: .ok,
                            headers: HTTPHeaders([("Content-Type", "application/json")]),
                            body: .init(data: data.isEmpty ? "{}".data(using: .utf8)! : data))
        }

        app.put("api", "show") { req async throws -> Response in
            let body = req.body.data.map { Data(buffer: $0) } ?? Data()
            await engine.applyShowData(body)
            return Response(status: .noContent)
        }

        app.get("api", "status") { req async -> Response in
            let status = await engine.currentStatus()
            let body = try JSONEncoder().encode(status)
            return Response(status: .ok,
                            headers: HTTPHeaders([("Content-Type", "application/json")]),
                            body: .init(data: body))
        }

        app.post("api", "command") { req async throws -> Response in
            let cmd = try req.content.decode(CommandPayload.self)
            await engine.handleCommand(cmd)
            return Response(status: .noContent)
        }

        // Designer UI
        app.get { req in
            req.eventLoop.future(Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/html; charset=utf-8")]),
                body: .init(string: DesignerUI.html(port: app.http.server.configuration.port))
            ))
        }

        // Serve all other routes with the SPA shell (client-side routing)
        app.get("**") { req in
            req.eventLoop.future(Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/html; charset=utf-8")]),
                body: .init(string: DesignerUI.html(port: app.http.server.configuration.port))
            ))
        }
    }
}
