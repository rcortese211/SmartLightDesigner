import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            // App title strip
            HStack {
                Text("SMARTLIGHT")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.accentGradient)
                    .kerning(2)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(SmartLightTheme.surfaceHigh)
            .overlay(alignment: .bottom) {
                GradientBar(height: 1)
            }

            // Navigation items
            List(AppTab.sidebarCases, selection: $state.selectedTab) { tab in
                HStack(spacing: 8) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 12))
                        .frame(width: 16)
                        .foregroundStyle(
                            state.selectedTab == tab
                                ? AnyShapeStyle(SmartLightTheme.accentGradient)
                                : AnyShapeStyle(Color(white: 0.5))
                        )
                    Text(tab.rawValue.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(
                            state.selectedTab == tab
                                ? AnyShapeStyle(SmartLightTheme.accentGradient)
                                : AnyShapeStyle(Color(white: 0.65))
                        )
                }
                .padding(.vertical, 5)
                .tag(tab)
                .listRowBackground(Group {
                    if state.selectedTab == tab {
                        SmartLightTheme.purple.opacity(0.12)
                            .overlay(alignment: .leading) {
                                SmartLightTheme.purple.opacity(0.8).frame(width: 2)
                            }
                    } else {
                        Color.clear
                    }
                })
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SmartLightTheme.surface)

            Divider().background(SmartLightTheme.border)
            universeStatus
        }
        .background(SmartLightTheme.surface)
        .navigationTitle("")
    }

    private var universeStatus: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(appState.isOutputEnabled ? SmartLightTheme.active : Color(white: 0.22))
                .frame(width: 10, height: 10)
            Text(appState.isOutputEnabled ? "LIVE" : "IDLE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(
                    appState.isOutputEnabled ? SmartLightTheme.active : Color(white: 0.35)
                )
            Spacer()
            if appState.isOutputEnabled {
                Text("\(appState.show.fixtures.count) FIX")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.purple.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SmartLightTheme.surfaceHigh)
    }
}
