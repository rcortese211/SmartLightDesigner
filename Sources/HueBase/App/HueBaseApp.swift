import SwiftUI

@main
struct HueBaseApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 1100, minHeight: 700)
                .hueBaseTheme()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            AppCommands(appState: appState)
        }

        Settings {
            OutputSettingsView()
                .environment(appState)
                .frame(width: 500)
        }
    }
}
