import AppKit
import ManOSUI
import LicenseKit
import SwiftUI

@main
struct ManOSApp: App {
    @State private var module: ManOSModule

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
        License.requireActivation(appName: "ManOS")
        _module = State(initialValue: ManOSModule())
    }

    var body: some Scene {
        Window("ManOS", id: "main") {
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
        Button("Open ManOS") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit ManOS") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
