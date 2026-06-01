import SwiftUI

struct SettingsSheetView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var settingsStatus: String = ""
    @State private var settingsStatusIsError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETTINGS")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.accentGradient)
                    .kerning(1.5)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(white: 0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(SmartLightTheme.surfaceHigh)
            .overlay(alignment: .bottom) { GradientBar(height: 1) }

            TabView {
                GeneralSettingsView()
                    .tabItem { Label("General", systemImage: "gear") }
                PatchView()
                    .tabItem { Label("Patch", systemImage: "cable.connector") }
                FixtureMapView()
                    .tabItem { Label("Map", systemImage: "map") }
                OutputSettingsView(
                    statusMessage: $settingsStatus,
                    statusIsError: $settingsStatusIsError
                )
                .tabItem { Label("Output", systemImage: "network") }
                BenchmarkView()
                    .tabItem { Label("Benchmark", systemImage: "gauge.with.needle") }
                SessionsSettingsView()
                    .tabItem { Label("Sessions", systemImage: "point.3.connected.trianglepath.dotted") }
            }
            .background(SmartLightTheme.background)

            // Status bar — shows feedback from output/discovery/pairing
            HStack(spacing: 6) {
                if !settingsStatus.isEmpty {
                    Circle()
                        .fill(settingsStatusIsError ? Color.red : Color(white: 0.4))
                        .frame(width: 5, height: 5)
                }
                Text(settingsStatus.isEmpty ? " " : settingsStatus)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settingsStatusIsError
                        ? Color.red.opacity(0.85)
                        : Color(white: 0.42))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(SmartLightTheme.surfaceHigh)
            .overlay(alignment: .top) { SmartLightTheme.border.frame(height: 1) }
        }
        .frame(minWidth: 860, minHeight: 580)
        .background(SmartLightTheme.background)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState

    private let intervalOptions: [(label: String, seconds: Int)] = [
        ("30 seconds", 30),
        ("1 minute",   60),
        ("2 minutes",  120),
        ("5 minutes",  300),
        ("10 minutes", 600),
        ("15 minutes", 900),
    ]

    var body: some View {
        @Bindable var state = appState
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Autosave")

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Automatically save to show file", isOn: $state.autosaveEnabled)

                    if appState.autosaveEnabled {
                        HStack {
                            Text("Interval")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color(white: 0.65))
                            Spacer()
                            Picker("", selection: $state.autosaveIntervalSeconds) {
                                ForEach(intervalOptions, id: \.seconds) { opt in
                                    Text(opt.label).tag(opt.seconds)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.currentShowURL != nil
                                  ? SmartLightTheme.active : Color(white: 0.3))
                            .frame(width: 6, height: 6)
                        if let url = appState.currentShowURL {
                            Text(url.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(white: 0.5))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("No file open — save or open a show to enable autosave")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(white: 0.4))
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(16)
                .background(SmartLightTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(SmartLightTheme.border, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .padding(.top, 20)
        }
        .background(SmartLightTheme.background)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.45))
            .kerning(1.2)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - A/B Crossfader Bar

struct ABCrossfaderBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        HStack(spacing: 10) {
            // Snap to A
            Button("A") { state.crossfade = 0 }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(appState.crossfade < 0.01
                    ? SmartLightTheme.active : Color(white: 0.38))
                .frame(width: 20)

            Text("PROG A")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(appState.crossfade < 0.5
                    ? SmartLightTheme.active.opacity(0.85) : Color(white: 0.28))

            Slider(value: $state.crossfade, in: 0...1)
                .tint(crossfaderColor)
                .frame(maxWidth: 260)

            Text("PROG B")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(appState.crossfade > 0.5
                    ? SmartLightTheme.purple.opacity(0.9) : Color(white: 0.28))

            // Snap to B
            Button("B") { state.crossfade = 1 }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(appState.crossfade > 0.99
                    ? SmartLightTheme.purple : Color(white: 0.38))
                .frame(width: 20)

            Divider().frame(height: 14)

            // Crossfade value readout
            Text(crossfadeLabel)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.35))
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(SmartLightTheme.surfaceHigh)
        .overlay(alignment: .top) { SmartLightTheme.border.frame(height: 1) }
    }

    private var crossfaderColor: Color {
        if appState.crossfade < 0.01 { return SmartLightTheme.active }
        if appState.crossfade > 0.99 { return SmartLightTheme.purple }
        return SmartLightTheme.blue
    }

    private var crossfadeLabel: String {
        if appState.crossfade < 0.01 { return "A" }
        if appState.crossfade > 0.99 { return "B" }
        return "\(Int(appState.crossfade * 100))%"
    }
}

// MARK: - Sessions Settings

struct SessionsSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Advanced mode gate
                advancedModeSection

                if appState.advancedModeEnabled {
                    piSetupSection
                    connectionSection
                    if appState.sessionClient != nil { sessionSection }
                }
            }
            .padding(.top, 20)
            .animation(.easeInOut(duration: 0.2), value: appState.advancedModeEnabled)
        }
        .background(SmartLightTheme.background)
        .sheet(isPresented: $showPiSetup) { PiSetupSheet() }
    }

    // MARK: Advanced mode toggle

    private var advancedModeSection: some View {
        Group {
            sectionHeader("Advanced User Mode")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable Pi Sessions & Remote Control", isOn: Binding(
                    get: { appState.advancedModeEnabled },
                    set: { appState.advancedModeEnabled = $0 }
                ))
                Text("When enabled, this Mac can join or control a SmartLight Pi running in Player mode. Sessions allow one Pi and multiple Macs to collaborate — the Pi handles all DMX output.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(SmartLightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(SmartLightTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    @State private var showPiSetup = false

    // MARK: Connect to Pi

    @State private var piAddressInput = ""
    @State private var isConnecting = false

    private var connectionSection: some View {
        Group {
            sectionHeader("Pi Connection")
            VStack(alignment: .leading, spacing: 10) {
                if let client = appState.sessionClient {
                    connectionStatusRow(client: client)
                } else {
                    HStack(spacing: 8) {
                        TextField("Pi IP address (e.g. 192.168.1.42)", text: $piAddressInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                        Button("Connect") {
                            let client = SessionClient()
                            appState.sessionClient = client
                            isConnecting = true
                            Task {
                                await client.connect(to: piAddressInput.trimmingCharacters(in: .whitespaces))
                                isConnecting = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SmartLightTheme.purple)
                        .disabled(piAddressInput.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                    }
                    if isConnecting {
                        ProgressView("Connecting…")
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
            .padding(16)
            .background(SmartLightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(SmartLightTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func connectionStatusRow(client: SessionClient) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(client.state.isConnected ? SmartLightTheme.active : Color.orange)
                .frame(width: 7, height: 7)
            Group {
                switch client.state {
                case .disconnected: Text("Disconnected")
                case .connecting:   Text("Connecting…")
                case .connectedIdle(_, let mode):
                    Text("Connected — Pi is in \(mode.rawValue.capitalized) mode")
                case .inSession(let s, _, let role, _):
                    Text("In session "\(s.sessionName)" as \(role.displayName)")
                case .error(let msg):
                    Text("Error: \(msg)").foregroundStyle(.red)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color(white: 0.75))

            Spacer()
            Button("Disconnect") {
                client.disconnect()
                appState.sessionClient = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: Session management

    @State private var myName = Host.current().localizedName ?? "Mac"
    @State private var selectedRole: SessionRole = .control
    @State private var newSessionName = ""
    @State private var showCreateSession = false
    @State private var selectedSessionId: String? = nil

    private var sessionSection: some View {
        Group {
            sectionHeader("Sessions")
            VStack(alignment: .leading, spacing: 12) {
                if let client = appState.sessionClient {
                    // Active session info
                    if case .inSession(let session, _, let role, _) = client.state {
                        activeSessionView(session: session, role: role, client: client)
                    } else {
                        // Session browser
                        sessionBrowserView(client: client)
                    }
                }
            }
            .padding(16)
            .background(SmartLightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(SmartLightTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func activeSessionView(session: SessionInfo, role: SessionRole, client: SessionClient) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.sessionName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text("Your role: \(role.displayName) — \(role.roleDescription)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Leave") { Task { await client.leaveSession() } }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }

        Divider().padding(.vertical, 4)

        // Session roster
        Text("PARTICIPANTS")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.4))
            .kerning(1)

        ForEach(session.clients) { participant in
            HStack(spacing: 6) {
                Circle()
                    .fill(SmartLightTheme.active)
                    .frame(width: 5, height: 5)
                Text(participant.name)
                    .font(.system(size: 11, design: .monospaced))
                Spacer()
                Text(participant.role.displayName)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(roleColor(participant.role))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(roleColor(participant.role).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }

        if let status = client.piStatus {
            Divider().padding(.vertical, 4)
            piStatusRow(status: status)
        }
    }

    @ViewBuilder
    private func sessionBrowserView(client: SessionClient) -> some View {
        // My name + role picker
        HStack(spacing: 8) {
            TextField("Your name", text: $myName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: 160)
            Picker("Role", selection: $selectedRole) {
                ForEach(SessionRole.allCases) { role in
                    Text(role.displayName).tag(role)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }
        Text(selectedRole.roleDescription)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color(white: 0.4))
            .fixedSize(horizontal: false, vertical: true)

        Divider().padding(.vertical, 4)

        // Session list
        HStack {
            Text("AVAILABLE SESSIONS")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.4))
                .kerning(1)
            Spacer()
            Button(action: { Task { await client.listSessions() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SmartLightTheme.purple)
        }

        if client.availableSessions.isEmpty {
            Text("No active sessions on this Pi.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(white: 0.35))
                .padding(.vertical, 4)
        } else {
            ForEach(client.availableSessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.sessionName)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Text("\(session.clients.count) participant\(session.clients.count == 1 ? "" : "s")")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color(white: 0.38))
                    }
                    Spacer()
                    Button("Join") {
                        Task { await client.joinSession(id: session.sessionId,
                                                        clientName: myName, role: selectedRole) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SmartLightTheme.purple)
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }

        Divider().padding(.vertical, 4)

        // Create new session
        if showCreateSession {
            HStack(spacing: 8) {
                TextField("Session name", text: $newSessionName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Button("Create") {
                    Task {
                        await client.createSession(sessionName: newSessionName,
                                                   clientName: myName,
                                                   role: selectedRole)
                        newSessionName = ""
                        showCreateSession = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(SmartLightTheme.active)
                .disabled(newSessionName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { showCreateSession = false; newSessionName = "" }
                    .buttonStyle(.bordered)
            }
        } else {
            Button("+ Create New Session") { showCreateSession = true }
                .buttonStyle(.bordered)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    @ViewBuilder
    private func piStatusRow(status: PiStatusPayload) -> some View {
        Text("PI STATUS")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.4))
            .kerning(1)
        HStack(spacing: 16) {
            labeledValue("Output", status.outputEnabled ? "ON" : "OFF",
                         color: status.outputEnabled ? SmartLightTheme.active : Color(white: 0.4))
            labeledValue("FPS", String(format: "%.0f", status.fps))
            labeledValue("TC", status.timecodeSource)
            if let cue = status.activeCueName { labeledValue("Cue", cue) }
        }
        .font(.system(size: 10, design: .monospaced))
    }

    private func labeledValue(_ label: String, _ value: String, color: Color = Color(white: 0.65)) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.38))
                .kerning(0.8)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func roleColor(_ role: SessionRole) -> Color {
        switch role {
        case .primary: SmartLightTheme.active
        case .control: SmartLightTheme.blue
        case .editor:  SmartLightTheme.purple
        }
    }

    // MARK: Pi Setup section

    private var piSetupSection: some View {
        Group {
            sectionHeader("Initial Pi Setup")
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Configure a fresh Pi")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Text("Given a Pi's IP address and SSH credentials, this will install Swift, clone the repo, compile the server, and install it as a systemd service that starts on boot.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                Button("Setup Pi…") { showPiSetup = true }
                    .buttonStyle(.borderedProminent)
                    .tint(SmartLightTheme.purple)
            }
            .padding(16)
            .background(SmartLightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(SmartLightTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.45))
            .kerning(1.2)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - Pi Setup Sheet

private struct PiSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var provisioner = PiProvisioner()

    @State private var ip         = ""
    @State private var username   = "pi"
    @State private var password   = ""
    @State private var mode       = "player"
    @State private var portString = "8080"
    @State private var repoURL    = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETUP PI")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.accentGradient)
                    .kerning(1.5)
                Spacer()
                if !provisioner.isRunning {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(SmartLightTheme.surfaceHigh)
            .overlay(alignment: .bottom) { GradientBar(height: 1) }

            if provisioner.stage == .idle {
                formContent
            } else {
                progressContent
            }
        }
        .frame(width: 540, height: 480)
        .background(SmartLightTheme.background)
    }

    // MARK: Form

    private var formContent: some View {
        VStack(spacing: 0) {
            Form {
                Section("Pi Connection") {
                    LabeledContent("IP Address") {
                        TextField("192.168.1.100", text: $ip)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    LabeledContent("Username") {
                        TextField("pi", text: $username)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    LabeledContent("Password") {
                        SecureField("SSH password", text: $password)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                Section("Service") {
                    LabeledContent("Mode") {
                        Picker("", selection: $mode) {
                            Text("Player").tag("player")
                            Text("Designer").tag("designer")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                    LabeledContent("Port") {
                        TextField("8080", text: $portString)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80)
                    }
                    LabeledContent("Repo URL") {
                        TextField("https://github.com/user/smartlight.git", text: $repoURL)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                Section {
                    Text("Connects over SSH, installs Swift 5.10 for aarch64, clones the repo, compiles the Pi server, and installs it as a systemd service. Requires 64-bit Raspberry Pi OS. Takes ~15–25 min on a Pi 4.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } header: { Text("About") }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Begin Setup") {
                    Task {
                        await provisioner.provision(
                            ip: ip.trimmingCharacters(in: .whitespaces),
                            username: username, password: password,
                            mode: mode, repoURL: repoURL,
                            port: Int(portString) ?? 8080)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(SmartLightTheme.purple)
                .disabled(ip.trimmingCharacters(in: .whitespaces).isEmpty ||
                          password.isEmpty || repoURL.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: Progress

    private var progressContent: some View {
        VStack(spacing: 0) {
            stageBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(SmartLightTheme.surfaceHigh)
                .overlay(alignment: .bottom) { SmartLightTheme.border.frame(height: 1) }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(provisioner.log.isEmpty ? "Starting…" : provisioner.log)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("logBottom")
                }
                .background(Color.black.opacity(0.4))
                .onChange(of: provisioner.log) { _, _ in
                    withAnimation { proxy.scrollTo("logBottom", anchor: .bottom) }
                }
            }

            Divider()
            HStack {
                switch provisioner.stage {
                case .done:
                    Label("Setup complete", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(SmartLightTheme.active)
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(SmartLightTheme.active)
                case .failed(let msg):
                    Text("✗ \(msg)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .lineLimit(2)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                default:
                    Text(provisioner.stage.label)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5))
                    Spacer()
                    Button("Cancel") { provisioner.cancel() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var stageBar: some View {
        let items: [(PiProvisioner.Stage, String)] = [
            (.connecting,        "SSH"),
            (.installingDeps,    "Deps"),
            (.installingSwift,   "Swift"),
            (.fetchingCode,      "Clone"),
            (.building,          "Build"),
            (.installingService, "Service"),
            (.done,              "Done")
        ]
        let current = items.firstIndex(where: { $0.0 == provisioner.stage }) ?? -1
        return HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let done   = i < current
                let active = i == current
                VStack(spacing: 4) {
                    Circle()
                        .fill(done   ? SmartLightTheme.active :
                              active ? SmartLightTheme.purple : Color(white: 0.22))
                        .frame(width: 9, height: 9)
                    Text(items[i].1)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(active ? SmartLightTheme.purple :
                                         done   ? SmartLightTheme.active : Color(white: 0.28))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
