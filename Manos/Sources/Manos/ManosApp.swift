import AppKit
import ManosUI
import SwiftUI

@main
struct ManosApp: App {
    @State private var module = ManosModule()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("manoS", id: "main") {
            module.window().frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Settings { module.settings() }

        MenuBarExtra {
            module.menuItems()
            Divider()
            AppMenuItems()
        } label: {
            Image(systemName: module.isPaused ? "hand.raised.slash"
                  : module.isControlling ? "hand.point.up.left.fill" : "hand.raised")
        }
    }
}

private struct AppMenuItems: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open manoS") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit manoS") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
