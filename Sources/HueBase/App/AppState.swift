import SwiftUI
import Observation
import AppKit

@Observable
final class AppState {
    var show = Show()
    var selectedTab: AppTab = .patch
    var isOutputEnabled = false
    var selectedFixtureIDs: Set<UUID> = []
    var selectedLayerID: UUID?
    var selectedCueID: UUID?
    var statusMessage: String = "Ready"

    let engine: DMXEngine
    let outputManager: DMXOutputManager
    let oscServer: OSCServer
    let scriptEngine: JSScriptEngine

    init() {
        let om = DMXOutputManager()
        let eng = DMXEngine(outputManager: om)
        self.engine = eng
        self.outputManager = om
        self.oscServer = OSCServer()
        self.scriptEngine = JSScriptEngine()
        setupDefaultProfiles()
        setupOSCHandlers()
    }

    private func setupDefaultProfiles() {
        show.fixtureProfiles = [
            FixtureProfile(
                id: UUID(), name: "Generic Dimmer", manufacturer: "Generic",
                channels: [FixtureChannel(id: UUID(), name: "Dimmer", offset: 0, defaultValue: 0)]
            ),
            FixtureProfile(
                id: UUID(), name: "Generic RGB", manufacturer: "Generic",
                channels: [
                    FixtureChannel(id: UUID(), name: "Red",   offset: 0, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Green", offset: 1, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Blue",  offset: 2, defaultValue: 0)
                ]
            ),
            FixtureProfile(
                id: UUID(), name: "Generic RGBW", manufacturer: "Generic",
                channels: [
                    FixtureChannel(id: UUID(), name: "Red",   offset: 0, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Green", offset: 1, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Blue",  offset: 2, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "White", offset: 3, defaultValue: 0)
                ]
            ),
            FixtureProfile(
                id: UUID(), name: "Generic RGBA", manufacturer: "Generic",
                channels: [
                    FixtureChannel(id: UUID(), name: "Red",   offset: 0, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Green", offset: 1, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Blue",  offset: 2, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Amber", offset: 3, defaultValue: 0)
                ]
            ),
            FixtureProfile(
                id: UUID(), name: "Moving Head (Basic)", manufacturer: "Generic",
                channels: [
                    FixtureChannel(id: UUID(), name: "Pan",       offset: 0, defaultValue: 128),
                    FixtureChannel(id: UUID(), name: "Tilt",      offset: 1, defaultValue: 128),
                    FixtureChannel(id: UUID(), name: "Dimmer",    offset: 2, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Red",       offset: 3, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Green",     offset: 4, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Blue",      offset: 5, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Strobe",    offset: 6, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "ColorWheel",offset: 7, defaultValue: 0)
                ]
            )
        ]
    }

    private func setupOSCHandlers() {
        oscServer.addHandler(address: "/sld/go") { [weak self] _ in
            self?.engine.cueEngine.go()
        }
        oscServer.addHandler(address: "/sld/back") { [weak self] _ in
            self?.engine.cueEngine.back()
        }
        oscServer.addHandler(address: "/sld/output/toggle") { [weak self] _ in
            DispatchQueue.main.async { self?.toggleOutput() }
        }
        oscServer.addHandler(address: "/sld/layer/opacity") { [weak self] msg in
            let args = msg.arguments
            guard args.count >= 2,
                  let idx = args[0].intValue,
                  let opacity = args[1].floatValue else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                guard idx >= 0 && idx < self.show.layers.count else { return }
                self.show.layers[idx].opacity = Double(opacity)
            }
        }
    }

    func toggleOutput() {
        isOutputEnabled.toggle()
        if isOutputEnabled {
            engine.start(show: show)
            statusMessage = "Output enabled"
        } else {
            engine.stop()
            statusMessage = "Output disabled"
        }
    }

    func saveShow() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sld") ?? .data]
        panel.nameFieldStringValue = show.name.isEmpty ? "Untitled" : show.name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder().encode(show)
            try data.write(to: url)
            statusMessage = "Saved: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func openShow() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sld") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            show = try JSONDecoder().decode(Show.self, from: data)
            statusMessage = "Opened: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Open failed: \(error.localizedDescription)"
        }
    }

    func newShow() {
        show = Show()
        setupDefaultProfiles()
        selectedFixtureIDs = []
        selectedLayerID = nil
        selectedCueID = nil
        statusMessage = "New show"
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case patch      = "Patch"
    case effects    = "Effects"
    case cues       = "Cues"
    case timeline   = "Timeline"
    case visualizer = "Visualizer"
    case output     = "Output"
    case scripting  = "Scripting"
    case benchmark  = "Benchmark"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .patch:      return "cable.connector"
        case .effects:    return "sparkles"
        case .cues:       return "list.number"
        case .timeline:   return "timeline.selection"
        case .visualizer: return "eye"
        case .output:     return "network"
        case .scripting:  return "terminal"
        case .benchmark:  return "gauge.with.needle"
        }
    }
}
