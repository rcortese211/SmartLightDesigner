import SwiftUI
import Observation
import AppKit
import UniformTypeIdentifiers

@Observable
final class AppState {
    var show = Show()
    var selectedTab: AppTab = .visualizer
    var isOutputEnabled = false
    var selectedFixtureIDs: Set<UUID> = []
    var selectedLayerID: UUID?
    var selectedCueID: UUID?
    var statusMessage: String = "Ready"

    var crossfade: Double = 0 {
        didSet { engine.crossfade = crossfade }
    }
    var programBLayers: [Layer] = [] {
        didSet { engine.programBLayers = programBLayers }
    }

    let engine: DMXEngine
    let outputManager: DMXOutputManager
    let oscServer: OSCServer
    let scriptEngine: JSScriptEngine
    let timecodeEngine: TimecodeEngine
    let bridgeDiscovery: HueBridgeDiscovery

    private var artNetTC: ArtNetTimecodeReceiver?
    private var networkTC: NetworkTimecodeSync?

    init() {
        let om  = DMXOutputManager()
        let eng = DMXEngine(outputManager: om)
        let tc  = TimecodeEngine()
        self.engine          = eng
        self.outputManager   = om
        self.oscServer       = OSCServer()
        self.scriptEngine    = JSScriptEngine()
        self.timecodeEngine  = tc
        self.bridgeDiscovery = HueBridgeDiscovery()
        setupDefaultProfiles()
        setupOSCHandlers()
        setupTimecodeCallbacks()
    }

    private func setupTimecodeCallbacks() {
        timecodeEngine.onTimecodeUpdate = { _ in
            // Drive the cue timeline when timecode is running
            // Full timeline-to-cue mapping can be wired here
        }
    }

    func applyTimecodeConfig() {
        let cfg = show.timecode
        artNetTC?.stop()
        networkTC?.stop()

        if cfg.smpteEnabled && cfg.smpteSource == .artNet {
            let receiver = ArtNetTimecodeReceiver(engine: timecodeEngine)
            receiver.port = cfg.artNetTimecodePort
            receiver.start()
            artNetTC = receiver
        }

        if cfg.networkSyncEnabled {
            let sync = NetworkTimecodeSync(engine: timecodeEngine, config: cfg)
            sync.start()
            networkTC = sync
        }
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
            ),
            FixtureProfile(
                id: UUID(), name: "Philips Hue Color", manufacturer: "Philips",
                channels: [
                    FixtureChannel(id: UUID(), name: "Red",   offset: 0, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Green", offset: 1, defaultValue: 0),
                    FixtureChannel(id: UUID(), name: "Blue",  offset: 2, defaultValue: 0)
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
            rebuildOutputDrivers()
            engine.start(show: show)
            applyTimecodeConfig()
            statusMessage = "Output enabled"
        } else {
            engine.stop()
            artNetTC?.stop()
            networkTC?.stop()
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

    func rebuildOutputDrivers() {
        while !outputManager.drivers.isEmpty { outputManager.removeDriver(at: 0) }
        if show.artNet.enabled  { outputManager.addDriver(ArtNetOutput(config: show.artNet)) }
        if show.sACN.enabled    { outputManager.addDriver(SACNOutput(config: show.sACN)) }
        if show.usbDMX.enabled  { outputManager.addDriver(USBDMXOutput(config: show.usbDMX)) }
        if show.hue.enabled     { outputManager.addDriver(PhilipsHueOutput(config: show.hue)) }
        if isOutputEnabled      { outputManager.startAll() }
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
    // Sidebar-visible tabs
    case visualizer = "Visualizer"
    case effects    = "Effects"
    case cues       = "Cues"
    case timeline   = "Timeline"
    case benchmark  = "Benchmark"
    // Settings-only (not in sidebar)
    case patch      = "Patch"
    case output     = "Output"
    case scripting  = "Scripting"

    var id: String { rawValue }

    var isInSidebar: Bool {
        switch self {
        case .patch, .output, .scripting: return false
        default: return true
        }
    }

    static var sidebarCases: [AppTab] { allCases.filter { $0.isInSidebar } }

    var systemImage: String {
        switch self {
        case .visualizer: return "eye"
        case .effects:    return "sparkles"
        case .cues:       return "list.number"
        case .timeline:   return "timeline.selection"
        case .benchmark:  return "gauge.with.needle"
        case .patch:      return "cable.connector"
        case .output:     return "network"
        case .scripting:  return "terminal"
        }
    }
}
