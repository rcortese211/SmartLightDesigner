import SwiftUI

struct CueListView: View {
    @Environment(AppState.self) private var appState
    @State private var editingCue: Cue?

    var cueEngine: CueEngine { appState.engine.cueEngine }

    var body: some View {
        HSplitView {
            cueTable
            if let cue = editingCue {
                CueEditorView(cue: cueBinding(cue))
                    .frame(minWidth: 260, maxWidth: 340)
            }
        }
        .navigationTitle("Cues")
        .toolbar {
            ToolbarItemGroup {
                Button(action: recordCue) {
                    Label("Record Cue", systemImage: "record.circle")
                }
                Button(action: deleteCue) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(appState.selectedCueID == nil)
                Divider()
                Button(action: { cueEngine.back() }) {
                    Label("Back", systemImage: "backward.fill")
                }
                Button(action: { cueEngine.go() }) {
                    Label("Go", systemImage: "forward.fill")
                }
                .buttonStyle(.borderedProminent)
                Button(action: { cueEngine.exitCueMode() }) {
                    Label("Stop", systemImage: "stop.fill")
                }
            }
        }
    }

    private var cueTable: some View {
        @Bindable var state = appState
        return Table(appState.show.cues, selection: $state.selectedCueID) {
            TableColumn("#") { cue in
                Text(String(format: "%.1f", cue.number))
                    .monospacedDigit()
                    .bold(cue.id == cueEngine.currentCue?.id)
            }
            .width(50)
            TableColumn("Name") { cue in
                Text(cue.name.isEmpty ? "—" : cue.name)
                    .foregroundStyle(cue.id == cueEngine.currentCue?.id ? Color.accentColor : .primary)
                    .onTapGesture(count: 2) { editingCue = cue }
            }
            TableColumn("Fade In") { cue in
                Text(String(format: "%.1fs", cue.fadeInTime))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Fade Out") { cue in
                Text(String(format: "%.1fs", cue.fadeOutTime))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .width(65)
            TableColumn("Follow") { cue in
                if let follow = cue.followTime {
                    Text(String(format: "%.1fs", follow)).monospacedDigit().foregroundStyle(.secondary)
                } else {
                    Text("Manual").foregroundStyle(.tertiary)
                }
            }
            .width(65)
            TableColumn("Notes") { cue in
                Text(cue.notes).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .onChange(of: appState.selectedCueID) { _, newID in
            if let id = newID {
                editingCue = appState.show.cues.first(where: { $0.id == id })
            }
        }
    }

    private func cueBinding(_ cue: Cue) -> Binding<Cue> {
        Binding(
            get: { appState.show.cues.first(where: { $0.id == cue.id }) ?? cue },
            set: { newValue in
                if let idx = appState.show.cues.firstIndex(where: { $0.id == cue.id }) {
                    appState.show.cues[idx] = newValue
                }
            }
        )
    }

    private func recordCue() {
        appState.show.addCue(from: appState.show.layers)
        appState.statusMessage = "Cue \(appState.show.cues.count) recorded"
    }

    private func deleteCue() {
        guard let id = appState.selectedCueID else { return }
        appState.show.cues.removeAll { $0.id == id }
        appState.selectedCueID = nil
        editingCue = nil
    }
}

struct CueEditorView: View {
    @Binding var cue: Cue

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("Number") {
                    TextField("", value: $cue.number, formatter: cueNumberFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                TextField("Name", text: $cue.name)
            }
            Section("Timing") {
                LabeledContent("Fade In") {
                    HStack {
                        Slider(value: $cue.fadeInTime, in: 0...30)
                        Text(String(format: "%.1fs", cue.fadeInTime))
                            .monospacedDigit().frame(width: 46)
                    }
                }
                LabeledContent("Fade Out") {
                    HStack {
                        Slider(value: $cue.fadeOutTime, in: 0...30)
                        Text(String(format: "%.1fs", cue.fadeOutTime))
                            .monospacedDigit().frame(width: 46)
                    }
                }
                Toggle("Auto Follow", isOn: Binding(
                    get: { cue.followTime != nil },
                    set: { cue.followTime = $0 ? 3.0 : nil }
                ))
                if cue.followTime != nil {
                    LabeledContent("Follow After") {
                        HStack {
                            Slider(value: Binding(
                                get: { cue.followTime ?? 3 },
                                set: { cue.followTime = $0 }
                            ), in: 0...60)
                            Text(String(format: "%.1fs", cue.followTime ?? 0))
                                .monospacedDigit().frame(width: 46)
                        }
                    }
                }
            }
            Section("Notes") {
                TextEditor(text: $cue.notes)
                    .frame(height: 80)
            }
        }
        .formStyle(.grouped)
    }

    private var cueNumberFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }
}
