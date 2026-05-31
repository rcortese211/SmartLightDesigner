import SwiftUI

struct OutputSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            artNetTab
                .tabItem { Label("Art-Net", systemImage: "network") }
            sacnTab
                .tabItem { Label("sACN / E1.31", systemImage: "dot.radiowaves.left.and.right") }
            usbTab
                .tabItem { Label("USB DMX", systemImage: "cable.connector") }
            oscTab
                .tabItem { Label("OSC", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .padding()
        .navigationTitle("Output")
    }

    private var artNetTab: some View {
        @Bindable var state = appState
        return Form {
            Toggle("Enable Art-Net Output", isOn: $state.show.artNet.enabled)
                .onChange(of: state.show.artNet.enabled) { _, enabled in
                    rebuildOutputDrivers()
                }
            if appState.show.artNet.enabled {
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
                        HStack {
                            Text("Internal \(mapping.localUniverse + 1)")
                            Image(systemName: "arrow.right")
                            Text("Art-Net")
                            TextField("", value: $mapping.outputUniverse, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                    }
                    Button("Add Mapping") {
                        let next = (appState.show.artNet.universeMappings.map(\.localUniverse).max() ?? -1) + 1
                        appState.show.artNet.universeMappings.append(
                            UniverseMapping(id: UUID(), localUniverse: next, outputUniverse: next)
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var sacnTab: some View {
        @Bindable var state = appState
        return Form {
            Toggle("Enable sACN Output", isOn: $state.show.sACN.enabled)
                .onChange(of: state.show.sACN.enabled) { _, _ in rebuildOutputDrivers() }
            if appState.show.sACN.enabled {
                Section("Settings") {
                    LabeledContent("Source Name") {
                        TextField("SmartLightDesigner", text: $state.show.sACN.sourceName)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Priority") {
                        Stepper("\(state.show.sACN.priority)", value: $state.show.sACN.priority, in: 0...200)
                    }
                    Toggle("Use Multicast", isOn: $state.show.sACN.useMulticast)
                }
                Section("Universe Mapping") {
                    ForEach($state.show.sACN.universeMappings) { $mapping in
                        HStack {
                            Text("Internal \(mapping.localUniverse + 1)")
                            Image(systemName: "arrow.right")
                            Text("sACN Universe")
                            TextField("", value: $mapping.outputUniverse, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder).frame(width: 60)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
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
        // Remove existing drivers, rebuild from current show config
        let manager = appState.outputManager
        while !manager.drivers.isEmpty { manager.removeDriver(at: 0) }

        let show = appState.show
        if show.artNet.enabled {
            manager.addDriver(ArtNetOutput(config: show.artNet))
        }
        if show.sACN.enabled {
            manager.addDriver(SACNOutput(config: show.sACN))
        }
        if show.usbDMX.enabled {
            manager.addDriver(USBDMXOutput(config: show.usbDMX))
        }

        if appState.isOutputEnabled {
            manager.startAll()
        }
    }

    private var portFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.allowsFloats = false
        f.minimum = 1; f.maximum = 65535
        return f
    }
}
