import AppKit
import SwiftUI
import OjosUI

@main
struct OjosApp: App {
    @State private var module = OjosModule()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("ojoS", id: "main") {
            module.window().frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Settings { module.settings() }

        MenuBarExtra {
            module.menuItems()
            Divider()
            AppMenuItems()
        } label: {
            Image(systemName: module.isRecording ? "record.circle.fill" : module.dwellClick ? "eye.circle.fill" : "eye")
        }
    }
}

private struct AppMenuItems: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open ojoS") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit ojoS") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
