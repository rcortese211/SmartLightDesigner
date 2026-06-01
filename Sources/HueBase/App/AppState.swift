import SwiftUI
import Observation
import AppKit
import UniformTypeIdentifiers

@Observable
final class AppState {
    var show = Show() {
        didSet {
            if !_suppressUndoRecording && !_loadingAutosave {
                let now = Date()
                if now.timeIntervalSince(_lastUndoPushDate) >= Self._undoCoalesceInterval {
                    _undoStack.append(oldValue)
                    if _undoStack.count > Self._maxUndoDepth { _undoStack.removeFirst() }
                    _redoStack.removeAll()
                    _lastUndoPushDate = now
                    canUndo = true
                    canRedo = false
                }
            }
            if !_loadingAutosave { scheduleAutosave() }
            engine.update(show: show)
        }
    }

    // MARK: - Undo / Redo

    /// True when there is at least one state to undo to.
    private(set) var canUndo: Bool = false
    /// True when there is at least one state to redo.
    private(set) var canRedo: Bool = false

    @ObservationIgnored private var _undoStack: [Show] = []
    @ObservationIgnored private var _redoStack: [Show] = []
    @ObservationIgnored private var _suppressUndoRecording = false
    @ObservationIgnored private var _lastUndoPushDate: Date = .distantPast
    private static let _undoCoalesceInterval: TimeInterval = 0.4
    private static let _maxUndoDepth = 50

    func undo() {
        // When a text input is focused and can undo typing, let it handle Cmd+Z.
        if let fr = NSApp.keyWindow?.firstResponder,
           (fr is NSTextView || fr is NSTextField),
           let um = fr.undoManager, um.canUndo { um.undo(); return }
        guard let prev = _undoStack.popLast() else { return }
        _redoStack.append(show)
        if _redoStack.count > Self._maxUndoDepth { _redoStack.removeFirst() }
        _suppressUndoRecording = true
        show = prev
        _suppressUndoRecording = false
        // Reset coalesce date so the next user action gets its own undo entry.
        _lastUndoPushDate = Date()
        canUndo = !_undoStack.isEmpty
        canRedo = true
        statusMessage = "Undo"
    }

    func redo() {
        if let fr = NSApp.keyWindow?.firstResponder,
           (fr is NSTextView || fr is NSTextField),
           let um = fr.undoManager, um.canRedo { um.redo(); return }
        guard let next = _redoStack.popLast() else { return }
        _undoStack.append(show)
        if _undoStack.count > Self._maxUndoDepth { _undoStack.removeFirst() }
        _suppressUndoRecording = true
        show = next
        _suppressUndoRecording = false
        _lastUndoPushDate = Date()
        canUndo = true
        canRedo = !_redoStack.isEmpty
        statusMessage = "Redo"
    }

    private func clearUndoHistory() {
        _undoStack.removeAll()
        _redoStack.removeAll()
        _lastUndoPushDate = .distantPast
        canUndo = false
        canRedo = false
    }
    var selectedTab: AppTab = .visualizer
    var isOutputEnabled = false
    var selectedFixtureIDs: Set<UUID> = []
    var selectedLayerID: UUID?
    var selectedCueID: UUID?
    var statusMessage: String = "Ready"

    // Recent files — persisted in UserDefaults, stale paths filtered out
    var recentFiles: [URL] {
        (UserDefaults.standard.stringArray(forKey: "recentShowFiles") ?? [])
            .compactMap { URL(string: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // True when the autosaved show has real content worth continuing
    var hasContinuableShow: Bool {
        !show.name.isEmpty || !show.fixtures.isEmpty || !show.layers.isEmpty
    }

    var crossfade: Double = 0 {
        didSet { engine.crossfade = crossfade }
    }
    var programBLayers: [Layer] = [] {
        didSet { engine.programBLayers = programBLayers }
    }
    var recalledPaletteIDOnA: UUID? = nil
    var recalledPaletteIDOnB: UUID? = nil
    var effectsSelectedFolderID: UUID? = nil
    var effectsSelectedPaletteID: UUID? = nil
    var effectsSelectedLayerID: UUID? = nil
    var outputSource: OutputSource = .effects

    // Advanced Pi session features — hidden behind advancedModeEnabled
    var advancedModeEnabled: Bool = UserDefaults.standard.bool(forKey: "advancedModeEnabled") {
        didSet { UserDefaults.standard.set(advancedModeEnabled, forKey: "advancedModeEnabled") }
    }
    var sessionClient: SessionClient? = nil
    var isInSession: Bool {
        guard let c = sessionClient else { return false }
        if case .inSession = c.state { return true }
        return false
    }

    // Current open file URL — set on save/open, cleared on new show
    var currentShowURL: URL?

    // Autosave-to-file settings — persisted in UserDefaults
    var autosaveEnabled: Bool = UserDefaults.standard.object(forKey: "autosaveEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(autosaveEnabled, forKey: "autosaveEnabled")
            autosaveEnabled ? startPeriodicAutosaveTimer() : stopPeriodicAutosaveTimer()
        }
    }
    var autosaveIntervalSeconds: Int = {
        let v = UserDefaults.standard.integer(forKey: "autosaveIntervalSeconds")
        return v > 0 ? v : 300
    }() {
        didSet {
            UserDefaults.standard.set(autosaveIntervalSeconds, forKey: "autosaveIntervalSeconds")
            if autosaveEnabled { startPeriodicAutosaveTimer() }
        }
    }

    let engine: DMXEngine
    let outputManager: DMXOutputManager
    let oscServer: OSCServer
    let scriptEngine: JSScriptEngine
    let timecodeEngine: TimecodeEngine
    let bridgeDiscovery: HueBridgeDiscovery
    let timelineEngine: TimelineEngine
    let audioPlayer: AudioPlayer

    private var artNetTC: ArtNetTimecodeReceiver?
    private var networkTC: NetworkTimecodeSync?
    private var _autosaveWork: DispatchWorkItem?
    private var _loadingAutosave = false
    @ObservationIgnored private var periodicAutosaveTimer: Timer?

    init() {
        let om  = DMXOutputManager()
        let eng = DMXEngine(outputManager: om)
        let tc  = TimecodeEngine()
        let tl  = TimelineEngine()
        let ap  = AudioPlayer()
        self.engine          = eng
        self.outputManager   = om
        self.oscServer       = OSCServer()
        self.scriptEngine    = JSScriptEngine()
        self.timecodeEngine  = tc
        self.bridgeDiscovery = HueBridgeDiscovery()
        self.timelineEngine  = tl
        self.audioPlayer     = ap
        tl.appState = self
        loadAutosave()
        if show.fixtureProfiles.isEmpty { setupDefaultProfiles() }
        if show.effectFolders.isEmpty   { seedDefaultEffectFolders() }
        setupOSCHandlers()
        setupTimecodeCallbacks()
        if autosaveEnabled { startPeriodicAutosaveTimer() }
    }

    deinit { periodicAutosaveTimer?.invalidate() }

    private func setupTimecodeCallbacks() {
        timecodeEngine.onTimecodeUpdate = { _ in
            // Drive the cue timeline when timecode is running
            // Full timeline-to-cue mapping can be wired here
        }
    }

    // MARK: - Auto-save

    private var autosaveURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SmartLight/autosave.sld")
    }

    private func scheduleAutosave() {
        _autosaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.autosave() }
        _autosaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func autosave() {
        guard let url = autosaveURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(show) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Periodic autosave to show file

    private func startPeriodicAutosaveTimer() {
        periodicAutosaveTimer?.invalidate()
        periodicAutosaveTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(autosaveIntervalSeconds),
            repeats: true
        ) { [weak self] _ in self?.saveToCurrentFileIfOpen() }
    }

    private func stopPeriodicAutosaveTimer() {
        periodicAutosaveTimer?.invalidate()
        periodicAutosaveTimer = nil
    }

    private func saveToCurrentFileIfOpen() {
        guard let url = currentShowURL,
              let data = try? JSONEncoder().encode(show) else { return }
        try? data.write(to: url, options: .atomic)
        DispatchQueue.main.async { self.statusMessage = "Autosaved" }
    }

    private func loadAutosave() {
        guard let url = autosaveURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(Show.self, from: data)
        else { return }
        _loadingAutosave = true
        show = saved
        _loadingAutosave = false
        clearUndoHistory()
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
        // In a Pi session the Mac never drives local DMX — relay to Pi instead
        if isInSession {
            let cmd = isOutputEnabled ? "output.off" : "output.on"
            Task { await sessionClient?.sendCommand(cmd) }
            statusMessage = isOutputEnabled ? "Output off (via Pi)" : "Output on (via Pi)"
            return
        }
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
            currentShowURL = url
            recordRecentFile(url)
            show.name = url.deletingPathExtension().lastPathComponent
            statusMessage = "Saved: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    /// Opens a show via an NSOpenPanel. Returns true if a file was successfully loaded.
    @discardableResult
    func openShow() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sld") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return openShow(url: url)
    }

    /// Opens a show directly from a URL (used by recent-file list).
    @discardableResult
    func openShow(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode(Show.self, from: data)
            clearUndoHistory()
            _suppressUndoRecording = true
            show = loaded
            _suppressUndoRecording = false
            if show.effectFolders.isEmpty { seedDefaultEffectFolders() }
            currentShowURL = url
            recordRecentFile(url)
            statusMessage = "Opened: \(url.lastPathComponent)"
            return true
        } catch {
            statusMessage = "Open failed: \(error.localizedDescription)"
            return false
        }
    }

    private func recordRecentFile(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: "recentShowFiles") ?? []
        let key = url.absoluteString
        paths.removeAll { $0 == key }
        paths.insert(key, at: 0)
        UserDefaults.standard.set(Array(paths.prefix(10)), forKey: "recentShowFiles")
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
        clearUndoHistory()
        _suppressUndoRecording = true
        show = Show()
        _suppressUndoRecording = false
        currentShowURL = nil
        setupDefaultProfiles()
        seedDefaultEffectFolders()
        selectedFixtureIDs = []
        selectedLayerID = nil
        selectedCueID = nil
        statusMessage = "New show"
        autosave()
    }
}

enum OutputSource: String, CaseIterable, Identifiable {
    case effects  = "Effects"
    case cues     = "Cues"
    case timeline = "Timeline"
    var id: String { rawValue }
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
        case .patch, .output, .scripting, .benchmark: return false
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
