import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            SidebarView()
        } detail: {
            detailView
                .background(HueBaseTheme.background)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(appState.show.name.isEmpty ? "HueBase" : appState.show.name)
                    .font(.headline)
                    .foregroundStyle(HueBaseTheme.accentGradient)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                OutputToggleButton()
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
        case .benchmark:  BenchmarkView()
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
        .tint(appState.isOutputEnabled ? HueBaseTheme.purple : .secondary)
        .buttonStyle(.bordered)
        .overlay(
            appState.isOutputEnabled
                ? RoundedRectangle(cornerRadius: 6)
                    .stroke(HueBaseTheme.accentGradient, lineWidth: 1)
                : nil
        )
        .help(appState.isOutputEnabled ? "Disable DMX output" : "Enable DMX output")
    }
}
