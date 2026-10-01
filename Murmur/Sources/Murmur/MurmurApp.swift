import AIKitUI
import AppKit
import LicenseKit
import MurmurUI
import SwiftUI

@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    private var module: MurmurModule { delegate.module }

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
        License.requireActivation(appName: "Murmur")
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created on first use, after activation.
    lazy var module = MurmurModule()

    /// Quitting mid-meeting or mid-note finalizes the audio first; otherwise it's unreadable.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            await module.prepareToQuit()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
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
