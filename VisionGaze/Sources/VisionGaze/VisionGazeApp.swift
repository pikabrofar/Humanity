import AppKit
import SwiftUI
import VisionGazeUI

@main
struct VisionGazeApp: App {
    @State private var module = VisionGazeModule()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("VisionGaze", id: "main") {
            module.window().frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Settings { module.settings() }

        MenuBarExtra {
            module.menuItems()
            Divider()
            AppMenuItems()
        } label: {
            Image(systemName: module.isRecording ? "record.circle.fill" : "eye")
        }
    }
}

private struct AppMenuItems: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open VisionGaze") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit VisionGaze") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
