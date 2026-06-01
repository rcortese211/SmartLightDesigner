import SwiftUI

private enum HuePairingState {
    case idle
    case pairing
    case success
    case failure(String)
}

struct OutputSettingsView: View {
    @Environment(AppState.self) private var appState
    var statusMessage: Binding<String>?
    var statusIsError: Binding<Bool>?
    @State private var huePairingState: HuePairingState = .idle
    @State private var hueDiscoveryStatus: String = ""
    @State private var applyConfirmation: String = ""

    var body: some View {
        TabView {
            artNetTab
                .tabItem { Label("Art-Net", systemImage: "network") }
            sacnTab
                .tabItem { Label("sACN / E1.31", systemImage: "dot.radiowaves.left.and.right") }
            usbTab
                .tabItem { Label("USB DMX", systemImage: "cable.connector") }
            hueTab
                .tabItem { Label("Philips Hue", systemImage: "lightbulb.fill") }
            oscTab
                .tabItem { Label("OSC", systemImage: "antenna.radiowaves.left.and.right") }
            timecodeTab
                .tabItem { Label("Timecode", systemImage: "clock") }
            audioOutputTab
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
        }
        .padding()
        .navigationTitle("Output")
    }

    private var artNetTab: some View {
        @Bindable var state = appState
        return Form {
            Toggle("Enable Art-Net Output", isOn: $state.show.artNet.enabled)
                .onChange(of: state.show.artNet.enabled) { _, _ in rebuildOutputDrivers() }
            Section("Network") {
                LabeledContent("Target IP") {
                    TextField("255.255.255.255", text: $state.show.artNet.targetIP)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Port") {
                    TextField("6454", value: $state.show.artNet.port, formatter: portFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
            Section("Universe Mapping") {
                ForEach($state.show.artNet.universeMappings) { $mapping in
                    universeMappingRow(local: $mapping.localUniverse,
                                      output: $mapping.outputUniverse,
                                      outputLabel: "Art-Net") {
                        state.show.artNet.universeMappings.removeAll { $0.id == mapping.id }
                    }
                }
                Button { addArtNetMapping() } label: {
                    Label("Add Mapping", systemImage: "plus")
                }
            }
            applySection("Art-Net") { rebuildOutputDrivers() }
        }
        .formStyle(.grouped)
    }

    private var sacnTab: some View {
        @Bindable var state = appState
        return Form {
            Toggle("Enable sACN Output", isOn: $state.show.sACN.enabled)
                .onChange(of: state.show.sACN.enabled) { _, _ in rebuildOutputDrivers() }
            Section("Settings") {
                LabeledContent("Source Name") {
                    TextField("SmartLight", text: $state.show.sACN.sourceName)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Priority") {
                    Stepper("\(state.show.sACN.priority)", value: $state.show.sACN.priority,
                            in: 0...200)
                }
                Toggle("Use Multicast", isOn: $state.show.sACN.useMulticast)
            }
            if !state.show.sACN.useMulticast {
                Section("Unicast Destinations") {
                    if state.show.sACN.unicastDestinations.isEmpty {
                        Text("No destinations added — packets will fall back to broadcast.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(state.show.sACN.unicastDestinations.indices, id: \.self) { idx in
                        HStack(spacing: 8) {
                            TextField("192.168.1.100", text: Binding(
                                get: { state.show.sACN.unicastDestinations[idx] },
                                set: { state.show.sACN.unicastDestinations[idx] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            Button {
                                state.show.sACN.unicastDestinations.remove(at: idx)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(Color.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        state.show.sACN.unicastDestinations.append("")
                    } label: {
                        Label("Add Destination", systemImage: "plus")
                    }
                }
            }
            Section("Universe Mapping") {
                ForEach($state.show.sACN.universeMappings) { $mapping in
                    universeMappingRow(local: $mapping.localUniverse,
                                      output: $mapping.outputUniverse,
                                      outputLabel: "sACN") {
                        state.show.sACN.universeMappings.removeAll { $0.id == mapping.id }
                    }
                }
                Button { addSACNMapping() } label: {
                    Label("Add Mapping", systemImage: "plus")
                }
            }
            applySection("sACN") { rebuildOutputDrivers() }
        }
        .formStyle(.grouped)
    }

    // Shared mapping row: [Internal ____] → [Label ____] [trash]
    private func universeMappingRow(
        local: Binding<Int>,
        output: Binding<Int>,
        outputLabel: String,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text("Internal")
                .foregroundStyle(.secondary)
                .fixedSize()
            TextField("", value: local, formatter: universeFormatter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 54)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            Text(outputLabel)
                .foregroundStyle(.secondary)
                .fixedSize()
            TextField("", value: output, formatter: universeFormatter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 54)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(Color.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    // Apply button row with a timed confirmation label
    @ViewBuilder
    private func applySection(_ label: String, action: @escaping () -> Void) -> some View {
        Section {
            HStack(spacing: 12) {
                Button("Apply \(label) Settings") {
                    action()
                    applyConfirmation = "\(label) applied ✓"
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        if applyConfirmation == "\(label) applied ✓" { applyConfirmation = "" }
                    }
                }
                .buttonStyle(.borderedProminent)
                if !applyConfirmation.isEmpty {
                    Label(applyConfirmation, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                        .font(.system(size: 12))
                        .transition(.opacity)
                }
            }
        }
    }

    private func addArtNetMapping() {
        let next = (appState.show.artNet.universeMappings.map(\.localUniverse).max() ?? -1) + 1
        appState.show.artNet.universeMappings.append(
            UniverseMapping(id: UUID(), localUniverse: next, outputUniverse: next)
        )
    }

    private func addSACNMapping() {
        let nextLocal = (appState.show.sACN.universeMappings.map(\.localUniverse).max() ?? -1) + 1
        let nextOutput = (appState.show.sACN.universeMappings.map(\.outputUniverse).max() ?? 0) + 1
        appState.show.sACN.universeMappings.append(
            UniverseMapping(id: UUID(), localUniverse: nextLocal, outputUniverse: nextOutput)
        )
    }

    private var usbTab: some View {
        @Bindable var state = appState
        return Form {
            Toggle("Enable USB DMX", isOn: $state.show.usbDMX.enabled)
                .onChange(of: state.show.usbDMX.enabled) { _, _ in rebuildOutputDrivers() }
            if appState.show.usbDMX.enabled {
                Section("Serial Port") {
                    LabeledContent("Port") {
                        TextField("/dev/cu.usbserial-XXXX", text: $state.show.usbDMX.portPath)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Universe") {
                        Stepper("Universe \(state.show.usbDMX.universe + 1)",
                                value: $state.show.usbDMX.universe, in: 0...255)
                    }
                    LabeledContent("Refresh Rate") {
                        Stepper("\(state.show.usbDMX.refreshRate) fps",
                                value: $state.show.usbDMX.refreshRate, in: 1...44)
                    }
                }
                Section {
                    Text("Connect an ENTTEC Open DMX or compatible USB-DMX interface. The port will appear in /dev/ after the FTDI driver is installed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            applySection("USB DMX") { rebuildOutputDrivers() }
        }
        .formStyle(.grouped)
    }

    private var oscTab: some View {
        @Bindable var state = appState
        return Form {
            Toggle("Enable OSC Server", isOn: $state.show.osc.enabled)
                .onChange(of: state.show.osc.enabled) { _, enabled in
                    if enabled { appState.oscServer.start(port: appState.show.osc.listenPort) }
                    else        { appState.oscServer.stop() }
                }
            if appState.show.osc.enabled {
                Section("Receive") {
                    LabeledContent("Listen Port") {
                        TextField("8000", value: $state.show.osc.listenPort, formatter: portFormatter)
                            .textFieldStyle(.roundedBorder).frame(width: 80)
                    }
                }
                Section("Send") {
                    LabeledContent("Target IP") {
                        TextField("127.0.0.1", text: $state.show.osc.sendIP)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Send Port") {
                        TextField("8001", value: $state.show.osc.sendPort, formatter: portFormatter)
                            .textFieldStyle(.roundedBorder).frame(width: 80)
                    }
                }
                Section("Available Commands") {
                    oscCommandRow("/sld/go", desc: "Advance to next cue")
                    oscCommandRow("/sld/back", desc: "Return to previous cue")
                    oscCommandRow("/sld/output/toggle", desc: "Toggle output on/off")
                    oscCommandRow("/sld/layer/opacity i f", desc: "Set layer opacity (index 0-based, value 0.0-1.0)")
                }
            }
            applySection("OSC") {
                if appState.show.osc.enabled {
                    appState.oscServer.stop()
                    appState.oscServer.start(port: appState.show.osc.listenPort)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func oscCommandRow(_ cmd: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cmd).font(.system(.caption, design: .monospaced))
            Text(desc).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func rebuildOutputDrivers() {
        appState.rebuildOutputDrivers()
    }

    // MARK: - Philips Hue

    private var hueTab: some View {
        @Bindable var state = appState
        return ScrollView {
            Form {
                Toggle("Enable Philips Hue Output", isOn: $state.show.hue.enabled)
                    .onChange(of: state.show.hue.enabled) { _, _ in rebuildOutputDrivers() }

                if appState.show.hue.enabled {
                    Section("Bridge") {
                        LabeledContent("Bridge IP") {
                            HStack {
                                TextField("192.168.1.x", text: $state.show.hue.bridgeIP)
                                    .textFieldStyle(.roundedBorder)
                                Button("Discover") { discoverHueBridges() }
                                    .buttonStyle(.bordered)
                            }
                        }
                        LabeledContent("API Key") {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    SecureField("Tap Pair after pressing link button", text: $state.show.hue.username)
                                        .textFieldStyle(.roundedBorder)
                                    huePairingIndicator
                                    Button(action: pairHueBridge) {
                                        if case .pairing = huePairingState {
                                            ProgressView().scaleEffect(0.6).frame(width: 40)
                                        } else {
                                            Text("Pair")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(appState.show.hue.bridgeIP.isEmpty)
                                }
                                Text("Press the physical button on the bridge, then click Pair within 30 seconds.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if case .failure(let msg) = huePairingState {
                                    Text(msg)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                } else if case .success = huePairingState {
                                    Text("Paired successfully — API key saved.")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        if !hueDiscoveryStatus.isEmpty {
                            LabeledContent("Discovery") {
                                Text(hueDiscoveryStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Update Rate") {
                            HStack {
                                Slider(value: $state.show.hue.updateRateHz, in: 1...20, step: 1)
                                Text("\(Int(state.show.hue.updateRateHz)) Hz")
                                    .monospacedDigit().frame(width: 50)
                            }
                        }
                    }

                    Section {
                        if appState.show.hue.lightMappings.isEmpty {
                            Text("No light mappings — add one below.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            // Header row
                            HStack(spacing: 8) {
                                Text("Name")
                                    .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
                                Text("Light ID")
                                    .frame(width: 60, alignment: .leading)
                                Text("Univ")
                                    .frame(width: 48, alignment: .leading)
                                Text("Addr")
                                    .frame(width: 48, alignment: .leading)
                                Spacer().frame(width: 28)
                            }
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(.bottom, 2)

                            ForEach($state.show.hue.lightMappings) { $m in
                                HStack(spacing: 8) {
                                    TextField("Name", text: $m.name)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(minWidth: 80, maxWidth: .infinity)
                                    TextField("1", text: $m.lightId)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                    TextField("0", value: $m.universe,
                                              formatter: NumberFormatter())
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 48)
                                    TextField("1", value: $m.startAddress,
                                              formatter: NumberFormatter())
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 48)
                                    Button {
                                        state.show.hue.lightMappings.removeAll { $0.id == m.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(Color.red.opacity(0.75))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 28)
                                }
                                .font(.callout)
                            }
                        }

                        Button(action: {
                            let next = appState.show.hue.lightMappings.count + 1
                            state.show.hue.lightMappings.append(
                                HueLightMapping(id: UUID(), name: "Light \(next)",
                                                lightId: "\(next)", universe: 0,
                                                startAddress: 1 + (next - 1) * 3)
                            )
                        }) {
                            Label("Add Light Mapping", systemImage: "plus")
                        }
                    } header: { Text("Light Mappings (Fixture → Hue Light)") }
                }
                applySection("Hue") { rebuildOutputDrivers() }
            }
            .formStyle(.grouped)
        }
    }

    private func setStatus(_ msg: String, isError: Bool = false) {
        statusMessage?.wrappedValue = msg
        statusIsError?.wrappedValue = isError
    }

    @ViewBuilder
    private var huePairingIndicator: some View {
        switch huePairingState {
        case .idle:    EmptyView()
        case .pairing: EmptyView()
        case .success:
            Circle()
                .fill(Color.green)
                .frame(width: 9, height: 9)
        case .failure:
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
        }
    }

    private func discoverHueBridges() {
        setStatus("Scanning local network…")
        appState.bridgeDiscovery.onDiscovered = { bridges in
            let ipv4Bridges = bridges.filter { $0.ip.contains(".") }
            if let first = ipv4Bridges.first {
                let current = appState.show.hue.bridgeIP
                if current.isEmpty || !current.contains(".") {
                    appState.show.hue.bridgeIP = first.ip
                }
                let msg = ipv4Bridges.count == 1
                    ? "Found: \(first.ip)"
                    : "Found \(ipv4Bridges.count) bridges — using \(first.ip)"
                hueDiscoveryStatus = msg
                setStatus(msg)
            } else {
                let msg = "No bridges found. Enter IP manually."
                hueDiscoveryStatus = msg
                setStatus(msg, isError: true)
            }
        }
        appState.bridgeDiscovery.onError = { msg in
            if !msg.contains("mDNS") {
                hueDiscoveryStatus = "Discovery error: \(msg)"
                setStatus("Discovery error: \(msg)", isError: true)
            }
        }
        appState.bridgeDiscovery.discover()
    }

    private func pairHueBridge() {
        huePairingState = .pairing
        setStatus("Waiting for bridge…")
        appState.bridgeDiscovery.pair(bridgeIP: appState.show.hue.bridgeIP) { result in
            switch result {
            case .success(let key):
                appState.show.hue.username = key
                huePairingState = .success
                setStatus("Paired successfully — API key saved.")
            case .failure(let err):
                huePairingState = .failure(err.localizedDescription)
                setStatus("Pair failed: \(err.localizedDescription)", isError: true)
            }
        }
    }

    // MARK: - Timecode

    private var timecodeTab: some View {
        @Bindable var state = appState
        return Form {
            // SMPTE / Art-Net Timecode
            Section("SMPTE Timecode") {
                Toggle("Enable SMPTE Receive", isOn: $state.show.timecode.smpteEnabled)
                    .onChange(of: state.show.timecode.smpteEnabled) { _, _ in
                        appState.applyTimecodeConfig()
                    }
                if appState.show.timecode.smpteEnabled {
                    Picker("Source", selection: $state.show.timecode.smpteSource) {
                        ForEach(TimecodeConfiguration.SMPTESource.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    Picker("Frame Rate", selection: $state.show.timecode.smpteFrameRate) {
                        ForEach(TimecodeFrameRate.allCases) { r in
                            Text(r.label).tag(r)
                        }
                    }
                    if appState.show.timecode.smpteSource == .artNet {
                        LabeledContent("Listen Port") {
                            TextField("6454", value: $state.show.timecode.artNetTimecodePort,
                                      formatter: portFormatter)
                                .textFieldStyle(.roundedBorder).frame(width: 80)
                        }
                    }
                }
            }

            // Network Timecode Sync
            Section("Network Timecode Sync") {
                Toggle("Enable Network Timecode", isOn: $state.show.timecode.networkSyncEnabled)
                    .onChange(of: state.show.timecode.networkSyncEnabled) { _, _ in
                        appState.applyTimecodeConfig()
                    }
                if appState.show.timecode.networkSyncEnabled {
                    Picker("Mode", selection: $state.show.timecode.networkSyncMode) {
                        ForEach(TimecodeConfiguration.NetworkSyncMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    LabeledContent("Port") {
                        TextField("5765", value: $state.show.timecode.networkSyncPort,
                                  formatter: portFormatter)
                            .textFieldStyle(.roundedBorder).frame(width: 80)
                    }
                    if appState.show.timecode.networkSyncMode == .master {
                        LabeledContent("Broadcast Address") {
                            TextField("255.255.255.255", text: $state.show.timecode.networkSyncBroadcast)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SmartLight Network Timecode is a custom UDP protocol (port 5765).")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Master instances broadcast at the current frame rate. Slave instances lock to the first master they hear.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Live status
            Section("Current Status") {
                LabeledContent("Source") {
                    Text(appState.timecodeEngine.source.rawValue)
                        .foregroundStyle(SmartLightTheme.purple)
                }
                LabeledContent("Position") {
                    Text(appState.timecodeEngine.current.description)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(SmartLightTheme.purple)
                }
                LabeledContent("Running") {
                    Text(appState.timecodeEngine.isRunning ? "Yes" : "No")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Audio Output

    private var audioOutputTab: some View {
        @Bindable var state = appState
        return Form {
            Section("Audio Output Device") {
                Picker("Output Device", selection: $state.show.audio.outputDeviceUID) {
                    Text("System Default").tag("")
                    ForEach(AudioPlayer.availableOutputDevices(), id: \.uid) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .onChange(of: appState.show.audio.outputDeviceUID) { _, uid in
                    appState.audioPlayer.setOutputDevice(uid: uid)
                }

                LabeledContent("Master Volume") {
                    HStack {
                        Slider(value: $state.show.audio.masterVolume, in: 0...1)
                        Text("\(Int(state.show.audio.masterVolume * 100))%")
                            .monospacedDigit().frame(width: 40)
                    }
                }
                .onChange(of: appState.show.audio.masterVolume) { _, v in
                    appState.audioPlayer.setVolume(v)
                }
            }

            Section {
                Text("Audio playback is used by the Timeline for music tracks. Select the output device here; it will be applied whenever the Timeline plays back audio.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var portFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.allowsFloats = false
        f.minimum = 1; f.maximum = 65535
        return f
    }

    private var universeFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.allowsFloats = false
        f.minimum = 0; f.maximum = 32767
        return f
    }
}
