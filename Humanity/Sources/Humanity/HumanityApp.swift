import AIKitUI
import AppKit
import GazeKit
import ManOSUI
import MurmurUI
import Observation
import OculOSUI
import SwiftUI

@main
struct HumanityApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var suite = Suite()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        // Everyday use happens in the menu bar panel; the window is for setup,
        // calibration and libraries, so it stays small.
        MenuBarExtra {
            QuickPanel().environment(suite).environment(suite.permissions)
        } label: {
            MenuBarIcon(suite: suite)
        }
        .menuBarExtraStyle(.window)

        Window("Humanity", id: "main") {
            SuiteView()
                .environment(suite)
                .environment(suite.permissions)
                .frame(minWidth: 640, minHeight: 420)
        }
        .defaultSize(width: 760, height: 500)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .help) {
                TutorialCommand()
            }
        }

        Window("Welcome to Humanity", id: "tutorial") {
            TutorialView().environment(suite).environment(suite.permissions)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            TabView {
                suite.gaze.settings().tabItem { Label("OculOS", systemImage: "eye") }
                suite.hands.settings().tabItem { Label("ManOS", systemImage: "hand.raised") }
                suite.voice.settings().tabItem { Label("Murmur", systemImage: "waveform") }
                AIProvidersView().tabItem { Label("AI Providers", systemImage: "sparkles") }
            }
        }
    }
}

/// Every module, sharing one camera so they can run side by side (and later
/// combine, e.g. look to target + pinch to click).
@MainActor @Observable
final class Suite {
    enum Module: String { case home, permissions, controls, ai, gaze, hands, voice }

    @ObservationIgnored let camera = CameraCapture()
    @ObservationIgnored let gaze: OculOSModule
    @ObservationIgnored let hands: ManOSModule
    @ObservationIgnored let voice = MurmurModule()
    @ObservationIgnored let permissions = SuitePermissions()
    var module: Module = .home

    /// SwiftUI only exposes `openWindow` inside views; the always-rendered menu
    /// bar icon hands it over so app-level events (Dock click, relaunch) can use it.
    @ObservationIgnored var openWindow: ((String) -> Void)?
    @ObservationIgnored static weak var current: Suite?

    var seenTutorial = UserDefaults.standard.bool(forKey: "Humanity.seenTutorial") {
        didSet { UserDefaults.standard.set(seenTutorial, forKey: "Humanity.seenTutorial") }
    }

    init() {
        // Created first, so OculOS configures the shared camera at the 1080p it needs.
        gaze = OculOSModule(camera: camera)
        hands = ManOSModule(camera: camera)
        // Development: `open Humanity.app --args -Humanity.start voice.library`
        if let start = UserDefaults.standard.string(forKey: "Humanity.start") { selection = start }
        Self.current = self
    }

    func showMainWindow() {
        openWindow?("main")
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Sidebar selection as "module.section", e.g. "hands.practice".
    var selection: String? {
        get {
            switch module {
            case .home: "home"
            case .permissions: "permissions"
            case .controls: "controls"
            case .ai: "ai"
            case .gaze: "gaze." + (gaze.selectedSection ?? "live")
            case .hands: "hands." + (hands.selectedSection ?? "live")
            case .voice: "voice." + (voice.selectedSection ?? "home")
            }
        }
        set {
            guard let newValue else { return }
            let parts = newValue.split(separator: ".", maxSplits: 1).map(String.init)
            module = Module(rawValue: parts[0]) ?? .home
            guard parts.count == 2 else { return }
            switch module {
            case .gaze: gaze.selectedSection = parts[1]
            case .hands: hands.selectedSection = parts[1]
            case .voice: voice.selectedSection = parts[1]
            default: break
            }
        }
    }
}

// MARK: - Main window

struct SuiteView: View {
    @Environment(Suite.self) private var suite
    @Environment(SuitePermissions.self) private var permissions
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var suite = suite
        NavigationSplitView {
            List(selection: $suite.selection) {
                Label("Home", systemImage: "house").tag("home")
                // The tag must be the outermost modifier, or List can't select the row.
                Label("Permissions", systemImage: "lock.shield")
                    .badge(permissions.missingRequired.count)
                    .tag("permissions")
                Label("Controls", systemImage: "keyboard").tag("controls")
                Label("AI Providers", systemImage: "sparkles").tag("ai")
                Section("OculOS · Eyes") {
                    ForEach(OculOSModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("gaze." + s.id)
                    }
                }
                Section("ManOS · Hands") {
                    ForEach(ManOSModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("hands." + s.id)
                    }
                }
                Section("Murmur · Voice") {
                    ForEach(MurmurModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("voice." + s.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 180)
        } detail: {
            switch suite.module {
            case .home: HomeView()
            case .permissions: PermissionsView()
            case .controls: ScrollView { ControlsList().padding(20) }.navigationTitle("Controls")
            case .ai: AIProvidersView().navigationTitle("AI Providers")
            case .gaze: suite.gaze.detail(for: suite.gaze.selectedSection ?? "live")
            case .hands: suite.hands.detail(for: suite.hands.selectedSection ?? "live")
            case .voice: suite.voice.detail(for: suite.voice.selectedSection ?? "home")
            }
        }
        .onAppear {
            if !suite.seenTutorial { openWindow(id: "tutorial") }
        }
    }
}

/// Compact overview: one row per module with its switch and main action.
struct HomeView: View {
    @Environment(Suite.self) private var suite
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your eyes, hands and voice, on this Mac only.")
                    .foregroundStyle(.secondary)
                PermissionsBanner()
                ModuleRows(compact: false)
                HStack {
                    Button("Show Tutorial") { openWindow(id: "tutorial") }
                    Text("Tip: everything here is also in the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .navigationTitle("Home")
    }
}

// MARK: - Menu bar panel

/// The everyday interface: one glance shows each module's state, one click runs it.
struct QuickPanel: View {
    @Environment(Suite.self) private var suite
    @Environment(\.openWindow) private var openWindow
    @State private var showControls = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Humanity").font(.headline)
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
                    .help("Settings")
            }

            PermissionsBanner(compact: true)
            ModuleRows(compact: true)

            DisclosureGroup("Controls", isExpanded: $showControls) {
                ControlsList(compact: true).padding(.top, 6)
            }
            .font(.callout)

            Divider()
            HStack {
                Button("Open Humanity") { open("main") }
                Button("Tutorial") { open("tutorial") }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(14)
        .frame(width: 320)
    }

    private func open(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Shared by the panel and Home: module, state, on/off, and its main action.
struct ModuleRows: View {
    @Environment(Suite.self) private var suite
    @Environment(\.openWindow) private var openWindow
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 8 : 10) {
            row(symbol: "eye", tint: .blue, name: "OculOS",
                status: !suite.gaze.isCalibrated ? "Not calibrated" : suite.gaze.isTracking ? "Tracking your gaze" : "Calibrated",
                isOn: Binding(get: { suite.gaze.isActive }, set: { suite.gaze.isActive = $0 })) {
                if suite.gaze.isCalibrated {
                    Toggle("Cursor", isOn: Binding(get: { suite.gaze.showCursor }, set: { suite.gaze.showCursor = $0 }))
                        .toggleStyle(.button)
                        .help("Show the gaze cursor")
                }
                Button(suite.gaze.isCalibrated ? "Recalibrate" : "Calibrate") { suite.gaze.startCalibration() }
            }
            row(symbol: "hand.raised", tint: .purple, name: "ManOS",
                status: !suite.hands.canControl ? "Needs Accessibility"
                    : suite.hands.isControlling ? (suite.hands.isPaused ? "Paused" : "Controlling the pointer")
                    : suite.hands.handInView ? "Hand in view" : "Off",
                isOn: Binding(get: { suite.hands.isActive }, set: { suite.hands.isActive = $0 })) {
                if suite.hands.canControl {
                    Button(suite.hands.isControlling ? "Stop  ⌃⌥⌘H" : "Control  ⌃⌥⌘H") { suite.hands.toggleControl() }
                        .tint(suite.hands.isControlling ? .red : nil)
                } else {
                    Button("Grant Access") { show("permissions") }
                }
            }
            row(symbol: "waveform", tint: .orange, name: "Murmur",
                status: !suite.voice.hasMicrophone ? "Needs microphone"
                    : suite.voice.isListening ? "Listening…" : "Hold ⌃⌥⌘D to dictate",
                isOn: nil) {
                if suite.voice.hasMicrophone {
                    Button(suite.voice.isListening ? "Stop" : "Dictate") { suite.voice.toggleDictation() }
                    Button("Note") { suite.voice.toggleNote() }.disabled(suite.voice.isListening)
                } else {
                    Button("Grant Access") { show("permissions") }
                }
            }
        }
    }

    private func show(_ selection: String) {
        suite.selection = selection
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func row<Actions: View>(symbol: String, tint: Color, name: String, status: String,
                                    isOn: Binding<Bool>?, @ViewBuilder actions: () -> Actions) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: compact ? 26 : 32, height: compact ? 26 : 32)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .opacity(isOn?.wrappedValue == false ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(compact ? .callout.weight(.semibold) : .headline)
                Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            HStack(spacing: 6) { actions() }
                .controlSize(.small)
                .disabled(isOn?.wrappedValue == false)
            if let isOn {
                Toggle("On", isOn: isOn).toggleStyle(.switch).controlSize(.mini).labelsHidden()
                    .help("Turn \(name)'s tracking off to save power")
            }
        }
        .padding(compact ? 8 : 12)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Controls cheat sheet

/// Every shortcut and gesture in one place.
struct ControlsList: View {
    var compact = false

    private let groups: [(String, String, [(String, String)])] = [
        ("OculOS", "eye", [
            ("Calibrate", "Menu bar → Calibrate · Esc cancels"),
            ("⌥⌘R", "Start or stop a gaze recording"),
            ("Click where you look", "Improves accuracy over time"),
        ]),
        ("ManOS", "hand.raised", [
            ("⌃⌥⌘H", "Turn hand control on or off (kill switch)"),
            ("Move palm", "Move the pointer"),
            ("Thumb + index pinch", "Click · hold and move to drag"),
            ("Thumb + middle pinch", "Right-click · hold and move to scroll"),
            ("Fist", "Hold the pointer while repositioning"),
            ("Flick up / down", "Next / previous video, page or slide"),
            ("Spread hand, still 1 s", "Pause or resume"),
        ]),
        ("Murmur", "waveform", [
            ("Hold ⌃⌥⌘D", "Talk, release to insert the text"),
            ("Tap ⌃⌥⌘D", "Start, tap again to stop"),
            ("Esc", "Cancel while listening"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            ForEach(groups, id: \.0) { name, symbol, items in
                VStack(alignment: .leading, spacing: 4) {
                    Label(name, systemImage: symbol).font(compact ? .caption.weight(.semibold) : .headline)
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                        ForEach(items, id: \.0) { key, action in
                            GridRow {
                                Text(key).font(.caption.monospaced().weight(.medium))
                                Text(action).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tutorial

/// Five short, skippable pages. Shown once on first launch; reopen from
/// Help or the menu bar.
struct TutorialView: View {
    @Environment(Suite.self) private var suite
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var page = 0

    private struct Page {
        let symbol: String
        let tint: Color
        let title: String
        let body: String
        let tips: [String]
    }

    private let pages: [Page] = [
        Page(symbol: "figure.arms.open", tint: .pink, title: "Welcome to Humanity",
             body: "Control your Mac with your eyes, hands and voice. Everything runs on this Mac; nothing is uploaded.",
             tips: ["Humanity lives in the menu bar. Click its icon for every control.",
                    "Turn modules on or off there to save power."]),
        Page(symbol: "eye", tint: .blue, title: "OculOS · Eyes",
             body: "A gaze cursor that follows where you look, plus heatmaps of what you looked at.",
             tips: ["Calibrate first: follow dots for about 45 seconds.",
                    "The cursor holds still while you read and jumps when your eyes move.",
                    "Clicking where you look teaches it to be more accurate."]),
        Page(symbol: "hand.raised", tint: .purple, title: "ManOS · Hands",
             body: "Move the pointer with your palm and pinch to click. Like a trackpad in the air.",
             tips: ["Pinch thumb + index to click, hold to drag.",
                    "Pinch thumb + middle to right-click or scroll.",
                    "Flick up for the next short video or page, down for the previous.",
                    "Make a fist to reposition. ⌃⌥⌘H turns it off instantly.",
                    "Rest your elbow on the desk; small movements are enough."]),
        Page(symbol: "waveform", tint: .orange, title: "Murmur · Voice",
             body: "Dictate into any app, and record notes with automatic summaries.",
             tips: ["Hold ⌃⌥⌘D, speak, release. The text appears where you're typing.",
                    "Esc cancels. Filler words are cleaned up automatically."]),
        Page(symbol: "checkmark.seal", tint: .green, title: "You're set",
             body: "Grant Humanity's permissions once, on one page, and every module can use them. Then calibrate OculOS when you want the gaze cursor.",
             tips: []),
    ]

    var body: some View {
        let p = pages[page]
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button("Skip") { finish() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
            }

            Image(systemName: p.symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(p.tint.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 6) {
                Text(p.title).font(.title2.weight(.semibold))
                Text(p.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !p.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(p.tips, id: \.self) { tip in
                        Label(tip, systemImage: "checkmark").font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if page == pages.count - 1 {
                Button("Grant Permissions") { finish(then: "permissions") }
                    .controlSize(.large)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Back") { withAnimation { page -= 1 } }
                    .opacity(page == 0 ? 0 : 1)
                    .disabled(page == 0)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle().fill(i == page ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
                Spacer()
                Button(page == pages.count - 1 ? "Done" : "Next") {
                    if page == pages.count - 1 { finish() } else { withAnimation { page += 1 } }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440, height: 470)
        .animation(.snappy, value: page)
    }

    private func finish(then selection: String? = nil) {
        suite.seenTutorial = true
        if let selection {
            suite.selection = selection
            openWindow(id: "main")
        }
        dismissWindow(id: "tutorial")
    }
}

private struct TutorialCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Humanity Tutorial") { openWindow(id: "tutorial") }
    }
}

/// Shown until every required permission is granted.
struct PermissionsBanner: View {
    @Environment(Suite.self) private var suite
    @Environment(SuitePermissions.self) private var permissions
    @Environment(\.openWindow) private var openWindow
    var compact = false

    var body: some View {
        let missing = permissions.missingRequired
        if !missing.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield").foregroundStyle(.orange)
                Text("\(missing.count) permission\(missing.count == 1 ? "" : "s") needed: \(missing.map(\.title).joined(separator: ", "))")
                    .font(.caption)
                    .lineLimit(compact ? 2 : 1)
                Spacer(minLength: 4)
                Button("Grant") {
                    suite.selection = "permissions"
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .controlSize(.small)
            }
            .padding(8)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

/// The menu bar icon is rendered at launch even when no window is open.
private struct MenuBarIcon: View {
    let suite: Suite
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: suite.voice.isListening ? "waveform.circle.fill"
              : suite.hands.isControlling ? "hand.point.up.left.fill"
              : suite.gaze.isRecording ? "record.circle.fill" : "figure.arms.open")
            .task {
                suite.openWindow = { openWindow(id: $0) }
                // Launching the app should always show it, even if its window was
                // closed last time (SwiftUI would otherwise restore "closed").
                suite.showMainWindow()
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Clicking the Dock icon or opening Humanity again while it runs.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { MainActor.assumeIsolated { Suite.current?.showMainWindow() } }
        return true
    }
}
