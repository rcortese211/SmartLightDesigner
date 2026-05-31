import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                detailView
                    .background(HueBaseTheme.background)
                    .frame(maxHeight: .infinity)
                ABCrossfaderBar()
                TimecodeBarView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(appState.show.name.isEmpty ? "HueBase" : appState.show.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HueBaseTheme.accentGradient)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                OutputToggleButton()
                Text(appState.statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .help("Patch & Output Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(isPresented: $showSettings)
                .environment(appState)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedTab {
        case .visualizer: VisualizerView()
        case .effects:    EffectsView()
        case .cues:       CueListView()
        case .timeline:   TimelineView()
        case .benchmark:  BenchmarkView()
        case .patch:      PatchView()
        case .output:     OutputSettingsView()
        case .scripting:  ScriptEditorView()
        }
    }
}

struct OutputToggleButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button(action: { appState.toggleOutput() }) {
            HStack(spacing: 5) {
                Circle()
                    .fill(appState.isOutputEnabled ? HueBaseTheme.active : Color(white: 0.3))
                    .frame(width: 7, height: 7)
                Text(appState.isOutputEnabled ? "OUTPUT ON" : "OUTPUT OFF")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(
            appState.isOutputEnabled
                ? HueBaseTheme.active.opacity(0.12)
                : HueBaseTheme.surface
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(
                    appState.isOutputEnabled ? HueBaseTheme.active : HueBaseTheme.border,
                    lineWidth: 1
                )
        )
        .cornerRadius(3)
        .foregroundStyle(
            appState.isOutputEnabled ? HueBaseTheme.active : Color.secondary
        )
        .help(appState.isOutputEnabled ? "Disable DMX output" : "Enable DMX output")
    }
}
