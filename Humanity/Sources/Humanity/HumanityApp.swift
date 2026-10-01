import AppKit
import GazeKit
import ManOSUI
import Observation
import SwiftUI
import VisionGazeUI

@main
struct HumanityApp: App {
    @State private var suite = Suite()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Humanity", id: "main") {
            SuiteView()
                .environment(suite)
                .frame(minWidth: 900, minHeight: 580)
        }
        .windowToolbarStyle(.unified)

        Settings {
            TabView {
                suite.gaze.settings().tabItem { Label("VisionGaze", systemImage: "eye") }
                suite.hands.settings().tabItem { Label("ManOS", systemImage: "hand.raised") }
            }
        }

        MenuBarExtra {
            Section("VisionGaze") { suite.gaze.menuItems() }
            Section("ManOS") { suite.hands.menuItems() }
            Divider()
            AppMenuItems()
        } label: {
            Image(systemName: suite.hands.isControlling ? "hand.point.up.left.fill"
                  : suite.gaze.isRecording ? "record.circle.fill" : "figure.arms.open")
        }
    }
}

/// Every module, sharing one camera so they can run side by side (and later
/// combine, e.g. look to target + pinch to click).
@MainActor @Observable
final class Suite {
    enum Module: String { case home, gaze, hands }

    @ObservationIgnored let camera = CameraCapture()
    @ObservationIgnored let gaze: VisionGazeModule
    @ObservationIgnored let hands: ManOSModule
    var module: Module = .home

    init() {
        // Created first, so VisionGaze configures the shared camera at the 1080p it needs.
        gaze = VisionGazeModule(camera: camera)
        hands = ManOSModule(camera: camera)
    }

    /// Sidebar selection as "module.section", e.g. "hands.practice".
    var selection: String? {
        get {
            switch module {
            case .home: "home"
            case .gaze: "gaze." + (gaze.selectedSection ?? "live")
            case .hands: "hands." + (hands.selectedSection ?? "live")
            }
        }
        set {
            guard let newValue else { return }
            let parts = newValue.split(separator: ".", maxSplits: 1).map(String.init)
            module = Module(rawValue: parts[0]) ?? .home
            if parts.count == 2 {
                if module == .gaze { gaze.selectedSection = parts[1] }
                if module == .hands { hands.selectedSection = parts[1] }
            }
        }
    }
}

struct SuiteView: View {
    @Environment(Suite.self) private var suite

    var body: some View {
        @Bindable var suite = suite
        NavigationSplitView {
            List(selection: $suite.selection) {
                Label("Home", systemImage: "house").tag("home")
                Section("Eyes · VisionGaze") {
                    ForEach(VisionGazeModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("gaze." + s.id)
                    }
                }
                Section("Hands · ManOS") {
                    ForEach(ManOSModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("hands." + s.id)
                    }
                }
                Section("Voice") {
                    Label("Coming soon", systemImage: "waveform").foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            switch suite.module {
            case .home: HomeView()
            case .gaze: suite.gaze.detail(for: suite.gaze.selectedSection ?? "live")
            case .hands: suite.hands.detail(for: suite.hands.selectedSection ?? "live")
            }
        }
    }
}

struct HomeView: View {
    @Environment(Suite.self) private var suite

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Humanity").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Control your Mac with your eyes and hands. Everything runs on this Mac; video never leaves it.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 16) {
                    ModuleCard(
                        name: "VisionGaze", tagline: "Eye tracking", symbol: "eye", tint: .blue,
                        isOn: Binding(get: { suite.gaze.isActive }, set: { suite.gaze.isActive = $0 }),
                        status: suite.gaze.isCalibrated
                            ? (suite.gaze.isTracking ? "Tracking your gaze" : "Calibrated")
                            : "Not calibrated yet",
                        good: suite.gaze.isCalibrated,
                        open: { suite.selection = "gaze." + (suite.gaze.isCalibrated ? "live" : "setup") }
                    )
                    ModuleCard(
                        name: "ManOS", tagline: "Hand gestures", symbol: "hand.raised", tint: .purple,
                        isOn: Binding(get: { suite.hands.isActive }, set: { suite.hands.isActive = $0 }),
                        status: !suite.hands.canControl ? "Needs Accessibility permission"
                            : suite.hands.isControlling ? "Controlling the pointer · ⌃⌥⌘H to stop"
                            : suite.hands.handInView ? "Hand in view" : "Ready",
                        good: suite.hands.canControl,
                        open: { suite.selection = "hands." + (suite.hands.canControl ? "live" : "setup") }
                    )
                    ModuleCard(
                        name: "Voice", tagline: "Dictation and summaries", symbol: "waveform", tint: .orange,
                        isOn: .constant(false), status: "Coming soon", good: false, open: nil
                    )
                }
            }
            .padding(28)
        }
        .navigationTitle("Home")
    }
}

private struct ModuleCard: View {
    let name: String
    let tagline: String
    let symbol: String
    let tint: Color
    @Binding var isOn: Bool
    let status: String
    let good: Bool
    let open: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                if open != nil {
                    Toggle("On", isOn: $isOn).toggleStyle(.switch).labelsHidden()
                        .help("Turning a module off stops its tracking to save power")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.title3.weight(.semibold))
                Text(tagline).foregroundStyle(.secondary)
            }
            Label(status, systemImage: good ? "checkmark.circle.fill" : "circle.dashed")
                .font(.callout)
                .foregroundStyle(good ? .green : .secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if let open {
                Button("Open", action: open).buttonStyle(.borderedProminent).tint(tint)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.separator.opacity(0.6)))
        .opacity(open == nil ? 0.6 : 1)
    }
}

private struct AppMenuItems: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Humanity") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Humanity") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
