import AIKitUI
import AppKit
import BocasUI
import SwiftUI

@main
struct BocasApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    private var module: BocasModule { delegate.module }

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("bocaS", id: "main") {
            module.window().frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Settings {
            TabView {
                module.settings().tabItem { Label("bocaS", systemImage: "waveform") }
                AIProvidersView().tabItem { Label("AI Providers", systemImage: "sparkles") }
            }
        }

        MenuBarExtra {
            module.menuItems()
            Divider()
            AppMenuItems()
        } label: {
            Image(systemName: module.isRecordingMeeting ? "record.circle.fill"
                  : module.isListening ? "waveform.circle.fill" : "waveform")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let module = BocasModule()

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
        Button("Open bocaS") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit bocaS") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
