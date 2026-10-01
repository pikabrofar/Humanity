import AIKitUI
import AppKit
import MurmurUI
import SwiftUI

@main
struct MurmurApp: App {
    @State private var module = MurmurModule()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Murmur", id: "main") {
            module.window().frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Settings {
            TabView {
                module.settings().tabItem { Label("Murmur", systemImage: "waveform") }
                AIProvidersView().tabItem { Label("AI Providers", systemImage: "sparkles") }
            }
        }

        MenuBarExtra {
            module.menuItems()
            Divider()
            AppMenuItems()
        } label: {
            Image(systemName: module.isListening ? "waveform.circle.fill" : "waveform")
        }
    }
}

private struct AppMenuItems: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Murmur") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Murmur") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
