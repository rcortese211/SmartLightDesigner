import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Lock window to splash dimensions until the user makes a choice
        DispatchQueue.main.async {
            guard let window = NSApp.mainWindow else { return }
            let splashSize = NSSize(width: 700, height: 440)
            window.setContentSize(splashSize)
            window.minSize = splashSize
            window.maxSize = splashSize
            window.center()
        }
    }
}

@main
struct HueBaseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .hueBaseTheme()
        }
        .defaultSize(width: 700, height: 440)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
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
