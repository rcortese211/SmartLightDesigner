import SwiftUI

struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { appState.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appState.canUndo)

            Button("Redo") { appState.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!appState.canRedo)
        }

        CommandGroup(replacing: .newItem) {
            Button("New Show") {
                appState.newShow()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Show…") {
                appState.openShow()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Save Show…") {
                appState.saveShow()
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandMenu("Output") {
            Button(appState.isOutputEnabled ? "Disable Output" : "Enable Output") {
                appState.toggleOutput()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        CommandMenu("Cue") {
            Button("Go") {
                appState.engine.cueEngine.go()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Back") {
                appState.engine.cueEngine.back()
            }
            .keyboardShortcut(.delete, modifiers: [])
        }
    }
}
