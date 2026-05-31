import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        List(AppTab.allCases, selection: $state.selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.systemImage)
                .tag(tab)
                .foregroundStyle(state.selectedTab == tab
                    ? AnyShapeStyle(HueBaseTheme.accentGradient)
                    : AnyShapeStyle(Color.primary))
        }
        .listStyle(.sidebar)
        .navigationTitle("HueBase")
        .safeAreaInset(edge: .top) {
            GradientBar(height: 3)
        }
        .safeAreaInset(edge: .bottom) {
            universeStatus
        }
    }

    private var universeStatus: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            HStack {
                Circle()
                    .fill(appState.isOutputEnabled ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(appState.isOutputEnabled ? "Live" : "Idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
