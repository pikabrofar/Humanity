import AppKit
import HandKit
import SwiftUI

@main
struct ManOSApp: App {
    @State private var model = AppModel()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("ManOS", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView().environment(model)
        }

        MenuBarExtra {
            MenuBarContent().environment(model)
        } label: {
            Image(systemName: model.engine.isPaused ? "hand.raised.slash"
                  : model.engine.isEnabled ? "hand.point.up.left.fill" : "hand.raised")
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $model.section) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    status(model.engine.activeHand != nil ? "Hand in view" : "No hand", model.engine.activeHand != nil ? .green : .orange)
                    status(model.canControl ? "Accessibility granted" : "Needs Accessibility", model.canControl ? .green : .red)
                    status(model.engine.isEnabled ? "Controlling" : "Off", model.engine.isEnabled ? .green : .secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        } detail: {
            switch model.section ?? .live {
            case .live: LiveView()
            case .setup: SetupView()
            case .practice: PracticeView()
            }
        }
    }

    private func status(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}

private struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(model.engine.isEnabled ? "Turn Off Hand Control" : "Turn On Hand Control") { model.toggleControl() }
            .keyboardShortcut("h", modifiers: [.control, .option, .command])
        Divider()
        Button("Open ManOS") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit ManOS") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        @Bindable var engine = model.engine
        Form {
            Section("Pointer") {
                Slider(value: $engine.profile.sensitivity, in: 0.3...3) { Text("Speed") }
                Picker("Hand", selection: $engine.dominantHand) {
                    Text("Right").tag(HandPose.Chirality.right)
                    Text("Left").tag(HandPose.Chirality.left)
                }
                Toggle("Show pinch ring at the pointer", isOn: $model.showHUD)
            }
            Section("Pinch") {
                LabeledContent("Click below") {
                    Slider(value: $engine.profile.pinchEnter, in: 0.1...0.7)
                }
                LabeledContent("Release above") {
                    Slider(value: $engine.profile.pinchExit, in: 0.2...0.9)
                }
                Text("Quick Setup sets these for your hand. The Live page shows your pinch against them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Scrolling") {
                Slider(value: $engine.profile.scrollSpeed, in: 200...2000) { Text("Speed") }
                Toggle("Reverse direction", isOn: $engine.profile.invertScroll)
            }
            Section {
                Button("Reset to Defaults") { engine.profile = HandProfile() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
