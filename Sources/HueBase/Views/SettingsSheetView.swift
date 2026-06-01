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
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(SmartLightTheme.surfaceHigh)
            .overlay(alignment: .bottom) { GradientBar(height: 1) }

            TabView {
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

// MARK: - A/B Crossfader Bar

struct ABCrossfaderBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        HStack(spacing: 10) {
            // Snap to A
            Button("A") { state.crossfade = 0 }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(appState.crossfade < 0.01
                    ? SmartLightTheme.active : Color(white: 0.38))
                .frame(width: 18)

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
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(appState.crossfade > 0.99
                    ? SmartLightTheme.purple : Color(white: 0.38))
                .frame(width: 18)

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
