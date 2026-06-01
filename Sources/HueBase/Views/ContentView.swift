import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(isPresented: $showSplash)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                mainInterface
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: showSplash)
        .onChange(of: showSplash) { _, isShowing in
            guard !isShowing else { return }
            // After the splash fade completes, unlock and expand to main app size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                guard let window = NSApp.mainWindow else { return }
                window.maxSize = NSSize(width: .greatestFiniteMagnitude,
                                        height: .greatestFiniteMagnitude)
                window.minSize = NSSize(width: 1100, height: 700)
                window.setContentSize(NSSize(width: 1280, height: 800))
                window.center()
            }
        }
    }

    private var mainInterface: some View {
        @Bindable var state = appState
        return NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                detailView
                    .background(SmartLightTheme.background)
                    .frame(maxHeight: .infinity)
                ABCrossfaderBar()
                TimecodeBarView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(appState.show.name.isEmpty ? "SmartLight Designer" : appState.show.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.accentGradient)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                OutputToggleButton()
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
                    .fill(appState.isOutputEnabled ? SmartLightTheme.active : Color(white: 0.3))
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
                ? SmartLightTheme.active.opacity(0.12)
                : SmartLightTheme.surface
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(
                    appState.isOutputEnabled ? SmartLightTheme.active : SmartLightTheme.border,
                    lineWidth: 1
                )
        )
        .cornerRadius(3)
        .foregroundStyle(
            appState.isOutputEnabled ? SmartLightTheme.active : Color.secondary
        )
        .help(appState.isOutputEnabled ? "Disable DMX output" : "Enable DMX output")
    }
}
