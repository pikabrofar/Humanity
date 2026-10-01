import AppKit
import GazeKit
import HandKit
import SwiftUI

/// Public entry point for hosting ManOS: the standalone app and the Humanity
/// suite both build their windows from this.
@MainActor
public final class ManOSModule {
    let model: AppModel

    /// - Parameter camera: A camera shared with other modules. Nil = own one.
    public init(camera: CameraCapture? = nil) {
        model = AppModel(camera: camera)
    }

    /// Sections for a host's sidebar, as (id, title, SF Symbol).
    public static let sections: [(id: String, title: String, symbol: String)] =
        SidebarSection.allCases.map { ($0.rawValue, $0.title, $0.symbol) }

    public var selectedSection: String? {
        get { model.section?.rawValue }
        set { model.section = newValue.flatMap(SidebarSection.init(rawValue:)) }
    }

    /// Whether hand tracking runs. Off saves CPU and releases control.
    public var isActive: Bool {
        get { model.engine.isActive }
        set { model.engine.isActive = newValue }
    }

    public var isControlling: Bool { model.engine.isEnabled }
    public var isPaused: Bool { model.engine.isPaused }
    public var canControl: Bool { model.canControl }
    public var handInView: Bool { model.engine.activeHand != nil }

    public func toggleControl() { model.toggleControl() }

    public func window() -> some View { RootView().environment(model) }

    public func detail(for section: String) -> some View {
        SectionDetail(section: SidebarSection(rawValue: section) ?? .live).environment(model)
    }

    public func settings() -> some View { SettingsView().environment(model) }

    public func menuItems() -> some View { MenuItems().environment(model) }
}

struct SectionDetail: View {
    let section: SidebarSection

    var body: some View {
        switch section {
        case .live: LiveView()
        case .setup: SetupView()
        case .practice: PracticeView()
        }
    }
}

struct MenuItems: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(model.engine.isEnabled ? "Turn Off Hand Control" : "Turn On Hand Control") { model.toggleControl() }
            .keyboardShortcut("h", modifiers: [.control, .option, .command])
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
            SectionDetail(section: model.section ?? .live)
        }
    }

    private func status(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
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
            Section("Flick") {
                Toggle(isOn: $engine.profile.flickEnabled) {
                    Text("Flick up or down to go to the next or previous item")
                    Text("Short videos (Shorts, TikTok, Reels), feeds, pages and slides. Flick up = next.")
                }
                Picker("Sends", selection: $engine.profile.flickAction) {
                    Text("Scroll").tag(HandProfile.FlickAction.scroll)
                    Text("Arrow keys ↓ ↑").tag(HandProfile.FlickAction.arrowKeys)
                }
                .disabled(!engine.profile.flickEnabled)
                LabeledContent("Needs") {
                    Slider(value: $engine.profile.flickDistance, in: 0.8...2.2) {
                        Text("Needs")
                    } minimumValueLabel: { Text("Small").font(.caption2) } maximumValueLabel: { Text("Big").font(.caption2) }
                }
                .disabled(!engine.profile.flickEnabled)
                if engine.profile.flickAction == .scroll {
                    Slider(value: $engine.profile.flickScrollAmount, in: 200...2000) { Text("Scroll per flick") }
                        .disabled(!engine.profile.flickEnabled)
                }
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
