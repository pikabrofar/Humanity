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
    @ObservationIgnored private var wasControlling = false

    var seenTutorial = UserDefaults.standard.bool(forKey: "Humanity.seenTutorial") {
        didSet { UserDefaults.standard.set(seenTutorial, forKey: "Humanity.seenTutorial") }
    }

    init() {
        // Created first, so OculOS configures the shared camera at the 1080p it needs.
        gaze = OculOSModule(camera: camera)
        hands = ManOSModule(camera: camera)
        // Both on: look to aim, pinch to click (research/19, Gaze + Pinch).
        hands.pointerSource = { [gaze] in gaze.isActive ? gaze.gazePoint : nil }
        // Development: `open Humanity.app --args -Humanity.start voice.library`
        if let start = UserDefaults.standard.string(forKey: "Humanity.start") { selection = start }
        Self.current = self

        // Lightweight by default: modules stay off until switched on, and the
        // camera is fully off (light off, no CPU) whenever no module needs it.
        gaze.isActive = UserDefaults.standard.bool(forKey: "Humanity.gazeOn")
        hands.isActive = UserDefaults.standard.bool(forKey: "Humanity.handsOn")
        watchModules()
    }

    /// Keeps the camera and the saved on/off state in sync with the modules,
    /// whichever way they were switched (panel, hotkey, module page).
    private func watchModules() {
        let defaults = UserDefaults.standard
        defaults.set(gaze.isActive, forKey: "Humanity.gazeOn")
        defaults.set(hands.isActive, forKey: "Humanity.handsOn")
        // Control switched off (e.g. ⌃⌥⌘H) also stops hand tracking, unless the
        // ManOS page is open and showing the camera.
        if wasControlling, !hands.isControlling, hands.isActive, module != .hands {
            hands.isActive = false
        }
        wasControlling = hands.isControlling
        camera.setPaused(!gaze.isActive && !hands.isActive)
        withObservationTracking {
            _ = (gaze.isActive, hands.isActive, hands.isControlling)
        } onChange: { [weak self] in
            Task { @MainActor in self?.watchModules() }
        }
    }

    func showMainWindow() { show(nil) }

    /// Opens a window, optionally at a sidebar selection.
    func show(_ selection: String?, window: String = "main") {
        if let selection { self.selection = selection }
        openWindow?(window)
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

/// Only for setup, calibration and libraries; everyday use is the menu bar.
struct SuiteView: View {
    @Environment(Suite.self) private var suite
    @Environment(SuitePermissions.self) private var permissions

    var body: some View {
        @Bindable var suite = suite
        NavigationSplitView {
            List(selection: $suite.selection) {
                Label("Home", systemImage: "house").tag("home")
                if !permissions.missingRequired.isEmpty {
                    // The tag must be the outermost modifier, or List can't select the row.
                    Label("Permissions", systemImage: "lock.shield")
                        .badge(permissions.missingRequired.count)
                        .tag("permissions")
                }
                Section("OculOS") {
                    ForEach(OculOSModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("gaze." + s.id)
                    }
                }
                Section("ManOS") {
                    ForEach(ManOSModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("hands." + s.id)
                    }
                }
                Section("Murmur") {
                    ForEach(MurmurModule.sections, id: \.id) { s in
                        Label(s.title, systemImage: s.symbol).tag("voice." + s.id)
                    }
                }
                Section("More") {
                    Label("AI Providers", systemImage: "sparkles").tag("ai")
                    Label("Permissions", systemImage: "lock.shield").tag("permissions")
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 170)
        } detail: {
            switch suite.module {
            case .home, .controls: HomeView()
            case .permissions: PermissionsView()
            case .ai: AIProvidersView().navigationTitle("AI Providers")
            case .gaze: suite.gaze.detail(for: suite.gaze.selectedSection ?? "live")
            case .hands: suite.hands.detail(for: suite.hands.selectedSection ?? "live")
            case .voice: suite.voice.detail(for: suite.voice.selectedSection ?? "home")
            }
        }
    }
}

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PermissionsBanner()
                ModuleTiles().frame(maxWidth: 300)
                ControlsList()
            }
            .padding(20)
            .frame(maxWidth: 520, alignment: .leading)
        }
        .navigationTitle("Humanity")
    }
}

// MARK: - Menu bar panel

/// The whole everyday interface: three glass toggles and one menu.
struct QuickPanel: View {
    @Environment(Suite.self) private var suite
    @Environment(SuitePermissions.self) private var permissions

    var body: some View {
        let missing = permissions.missingRequired.count
        VStack(spacing: 12) {
            ModuleTiles()
            HStack(spacing: 6) {
                if missing > 0 {
                    Button { suite.show("permissions") } label: {
                        Label("\(missing) permission\(missing == 1 ? "" : "s") needed", systemImage: "exclamationmark.triangle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                } else {
                    Text("⌃⌥⌘D dictate · ⌃⌥⌘H hands").foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Open Humanity") { suite.show("home") }
                    Button("Tutorial") { suite.show(nil, window: "tutorial") }
                    SettingsLink { Text("Settings…") }
                    Divider()
                    Button("Quit Humanity") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 236)
    }
}

/// One glass button per module: tap toggles it, tap the name to open its page.
struct ModuleTiles: View {
    @Environment(Suite.self) private var suite

    var body: some View {
        let gaze = suite.gaze, hands = suite.hands, voice = suite.voice
        HStack(alignment: .top, spacing: 8) {
            Tile(symbol: "eye", name: "OculOS", tint: .blue, isOn: gaze.isActive,
                 status: !gaze.isActive ? "Off" : !gaze.isCalibrated ? "Calibrate" : gaze.isTracking ? "Tracking" : "Searching",
                 help: "Eye tracking") {
                gaze.isActive.toggle()
                gaze.showCursor = gaze.isActive && gaze.isCalibrated
                if gaze.isActive, !gaze.isCalibrated { suite.show("gaze.setup") }
            } open: { suite.show("gaze." + (gaze.isCalibrated ? "live" : "setup")) }

            let handsOn = hands.isActive && hands.isControlling
            Tile(symbol: "hand.raised", name: "ManOS", tint: .purple, isOn: handsOn,
                 status: !handsOn ? (hands.canControl ? "Off" : "No access") : hands.isPaused ? "Paused" : hands.handInView ? "Active" : "No hand",
                 help: "Hand control · ⌃⌥⌘H") {
                if handsOn { hands.isActive = false; return }
                guard hands.canControl else { suite.show("permissions"); return }
                hands.isActive = true
                if !hands.isControlling { hands.toggleControl() }
            } open: { suite.show("hands.live") }

            Tile(symbol: voice.isListening ? "stop.fill" : "waveform", name: "Murmur", tint: .orange, isOn: voice.isListening,
                 status: !voice.hasMicrophone ? "No mic" : voice.isListening ? "Listening" : "Ready",
                 help: "Dictate · hold ⌃⌥⌘D") {
                voice.hasMicrophone ? voice.toggleDictation() : suite.show("permissions")
            } open: { suite.show("voice.home") }
        }
    }
}

private struct Tile: View {
    let symbol: String, name: String, tint: Color, isOn: Bool, status: String, help: String
    let toggle: () -> Void
    let open: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: toggle) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .modifier(Glass(tint: isOn ? tint : nil))
            .help(help)
            Button(action: open) {
                VStack(spacing: 1) {
                    Text(name).font(.caption.weight(.semibold))
                    Text(status).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .help("Open \(name)")
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}

/// Liquid Glass on macOS 26 (tinted when on); a tinted circle before that.
private struct Glass: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if let tint {
                content.buttonStyle(.glassProminent).tint(tint).buttonBorderShape(.circle)
            } else {
                content.buttonStyle(.glass).buttonBorderShape(.circle)
            }
        } else {
            content.buttonStyle(.plain)
                .background(tint.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(.quaternary), in: Circle())
        }
    }
}

// MARK: - Controls cheat sheet

/// Every shortcut and gesture in one place.
struct ControlsList: View {
    private let groups: [(String, String, [(String, String)])] = [
        ("OculOS", "eye", [
            ("Calibrate", "Menu bar → Calibrate · Esc cancels"),
            ("⌥⌘R", "Start or stop a gaze recording"),
            ("Click where you look", "Improves accuracy over time"),
        ]),
        ("ManOS", "hand.raised", [
            ("⌃⌥⌘H", "Turn hand control on or off (kill switch)"),
            ("Open hand, move palm", "Move the pointer"),
            ("Thumb + index pinch", "Click · hold and move to drag"),
            ("Thumb + middle pinch", "Right-click · hold and move to scroll"),
            ("Fist", "Hold the pointer while repositioning"),
            ("Curl 3 fingers + pinch", "Anchored click: the pointer can't drift"),
            ("Flick up / down", "Next / previous video, page or slide"),
            ("Spread hand, still 1.5 s", "Pause · ⌃⌥⌘H also resumes"),
        ]),
        ("Murmur", "waveform", [
            ("Hold ⌃⌥⌘D", "Talk, release to insert the text"),
            ("Tap ⌃⌥⌘D", "Start, tap again to stop"),
            ("Esc", "Cancel while listening"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups, id: \.0) { name, symbol, items in
                VStack(alignment: .leading, spacing: 4) {
                    Label(name, systemImage: symbol).font(.headline)
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
                    "For pinpoint clicks, curl your middle, ring and little fingers (the pointer locks), then pinch.",
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


/// Shown until every required permission is granted.
struct PermissionsBanner: View {
    @Environment(Suite.self) private var suite
    @Environment(SuitePermissions.self) private var permissions

    var body: some View {
        let missing = permissions.missingRequired
        if !missing.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield").foregroundStyle(.orange)
                Text("\(missing.count) permission\(missing.count == 1 ? "" : "s") needed: \(missing.map(\.title).joined(separator: ", "))")
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button("Grant") { suite.show("permissions") }
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
                // A menu bar app stays out of the way: a window only on first launch
                // (the tutorial) or when asked for.
                if !suite.seenTutorial {
                    openWindow(id: "tutorial")
                    NSApp.activate(ignoringOtherApps: true)
                } else if UserDefaults.standard.string(forKey: "Humanity.start") != nil {
                    suite.showMainWindow()
                }
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
