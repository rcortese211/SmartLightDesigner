import SwiftUI

struct ScriptEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var source: String = defaultScript
    @State private var selectedScriptId: UUID?
    @State private var newScriptName: String = ""

    var scriptEngine: JSScriptEngine { appState.scriptEngine }

    var body: some View {
        HSplitView {
            scriptLibrary
                .frame(minWidth: 180, maxWidth: 220)
            editorPanel
        }
        .navigationTitle("Scripting")
        .onAppear { scriptEngine.bind(engine: appState.engine) }
    }

    private var scriptLibrary: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scripts").font(.headline)
                Spacer()
                Button(action: addScript) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal).padding(.vertical, 8)
            Divider()
            List(appState.show.savedScripts, selection: $selectedScriptId) { script in
                Text(script.name)
                    .tag(script.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            appState.show.savedScripts.removeAll { $0.id == script.id }
                            if selectedScriptId == script.id { selectedScriptId = nil }
                        }
                    }
                    .onTapGesture(count: 2) { loadScript(script) }
            }
            .listStyle(.plain)
        }
    }

    private var editorPanel: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            HSplitView {
                TextEditor(text: $source)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Console").font(.caption).bold().foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") { scriptEngine.clearOutput() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    Divider()
                    ScrollView {
                        Text(scriptEngine.consoleOutput.isEmpty ? "No output" : scriptEngine.consoleOutput)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(scriptEngine.consoleOutput.isEmpty ? .tertiary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                }
                .frame(minWidth: 200)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            }
        }
    }

    private var editorToolbar: some View {
        HStack {
            Button(action: run) {
                Label("Run", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(scriptEngine.isRunning)

            Button(action: saveScript) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)

            Spacer()

            Menu("Templates") {
                Button("Rainbow Chase") { source = rainbowChaseTemplate }
                Button("Ping Pong") { source = pingPongTemplate }
                Button("Blackout") { source = blackoutTemplate }
            }
            .menuStyle(.button)
        }
        .padding(.horizontal).padding(.vertical, 6)
    }

    private func run() {
        scriptEngine.execute(source)
    }

    private func addScript() {
        let script = SavedScript(name: "Script \(appState.show.savedScripts.count + 1)", source: source)
        appState.show.savedScripts.append(script)
        selectedScriptId = script.id
    }

    private func saveScript() {
        if let id = selectedScriptId,
           let idx = appState.show.savedScripts.firstIndex(where: { $0.id == id }) {
            appState.show.savedScripts[idx].source = source
        } else {
            addScript()
        }
    }

    private func loadScript(_ script: SavedScript) {
        source = script.source
        selectedScriptId = script.id
    }
}

private let defaultScript = """
// HueBase Script
// Available functions:
//   setChannel(universe, channel, value)  — universe 0-based, channel 0-511, value 0-255
//   sleep(ms)                             — pause for N milliseconds
//   getTime()                             — seconds since reference date
//   console.log(msg)                      — print to console

console.log("Script started at t=" + getTime().toFixed(2));

// Example: flash channel 0 of universe 0 three times
for (var i = 0; i < 3; i++) {
    setChannel(0, 0, 255);
    sleep(200);
    setChannel(0, 0, 0);
    sleep(200);
}

console.log("Done.");
"""

private let rainbowChaseTemplate = """
// Rainbow chase — loops indefinitely (stop with the Run button)
var t = 0;
while (true) {
    for (var ch = 0; ch < 30; ch++) {
        var hue = (ch / 30.0 + t * 0.05) % 1.0;
        var rgb = hsvToRgb(hue, 1, 1);
        setChannel(0, ch * 3,     rgb[0]);
        setChannel(0, ch * 3 + 1, rgb[1]);
        setChannel(0, ch * 3 + 2, rgb[2]);
    }
    sleep(30);
    t++;
}

function hsvToRgb(h, s, v) {
    var i = Math.floor(h * 6), f = h * 6 - i;
    var p = v*(1-s), q = v*(1-f*s), t2 = v*(1-(1-f)*s);
    switch (i % 6) {
        case 0: return [v*255, t2*255, p*255];
        case 1: return [q*255, v*255, p*255];
        case 2: return [p*255, v*255, t2*255];
        case 3: return [p*255, q*255, v*255];
        case 4: return [t2*255, p*255, v*255];
        default: return [v*255, p*255, q*255];
    }
}
"""

private let pingPongTemplate = """
// Ping pong — bounce a single lit fixture back and forth
var pos = 0, dir = 1, total = 12;
while (true) {
    for (var i = 0; i < total; i++) {
        setChannel(0, i * 3,     i === pos ? 255 : 0);
        setChannel(0, i * 3 + 1, 0);
        setChannel(0, i * 3 + 2, i === pos ? 200 : 0);
    }
    pos += dir;
    if (pos >= total - 1 || pos <= 0) dir *= -1;
    sleep(80);
}
"""

private let blackoutTemplate = """
// Blackout all channels on universe 0
for (var ch = 0; ch < 512; ch++) {
    setChannel(0, ch, 0);
}
console.log("Blackout applied.");
"""
