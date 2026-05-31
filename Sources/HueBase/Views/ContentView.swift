import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            SidebarView()
        } detail: {
            detailView
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(appState.show.name.isEmpty ? "Untitled Show" : appState.show.name)
                    .font(.headline)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                OutputToggleButton()
                Spacer()
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedTab {
        case .patch:      PatchView()
        case .effects:    EffectsView()
        case .cues:       CueListView()
        case .timeline:   TimelineView()
        case .visualizer: VisualizerView()
        case .output:     OutputSettingsView()
        case .scripting:  ScriptEditorView()
        }
    }
}

struct OutputToggleButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button(action: { appState.toggleOutput() }) {
            Label(
                appState.isOutputEnabled ? "Output On" : "Output Off",
                systemImage: appState.isOutputEnabled ? "bolt.fill" : "bolt.slash"
            )
        }
        .tint(appState.isOutputEnabled ? .green : .secondary)
        .buttonStyle(.bordered)
        .help(appState.isOutputEnabled ? "Disable DMX output" : "Enable DMX output")
    }
}
