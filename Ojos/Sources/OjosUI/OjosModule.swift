import GazeKit
import SwiftUI

/// Public entry point for hosting ojoS: the standalone app and the
/// Sentidos suite both build their windows from this.
@MainActor
public final class OjosModule {
    let model: AppModel

    /// - Parameter camera: A camera shared with other modules. Nil = own one.
    public init(camera: CameraCapture? = nil) {
        model = AppModel(camera: camera)
    }

    /// Sections for a host's sidebar, as (id, title, SF Symbol).
    public static let sections: [(id: String, title: String, symbol: String)] =
        SidebarSection.allCases.map { ($0.rawValue, $0.title, $0.symbol) }

    /// The section the module wants shown (it navigates itself, e.g. after setup).
    public var selectedSection: String? {
        get { model.section?.rawValue }
        set { model.section = newValue.flatMap(SidebarSection.init(rawValue:)) }
    }

    /// Whether gaze tracking runs. Off saves CPU when only other modules are used.
    public var isActive: Bool {
        get { model.engine.isActive }
        set { model.engine.isActive = newValue }
    }

    public var isCalibrated: Bool { model.engine.isCalibrated }
    public var isTracking: Bool { model.engine.gaze != nil }
    public var isRecording: Bool { model.isRecording }

    public var showCursor: Bool {
        get { model.showCursor }
        set { model.showCursor = newValue }
    }

    /// Dwell clicking. Always off at launch; hosts can disarm it from a kill switch.
    public var dwellClick: Bool {
        get { model.dwellClick }
        set { model.dwellClick = newValue }
    }

    /// Where the user is looking, in global display points (top-left origin, as
    /// CGEvent uses); nil when not tracking.
    public var gazePoint: CGPoint? { model.gazePoint }

    /// Clicks where the user is looking (snapped to the nearest control when
    /// enabled), for a host trigger such as a manoS pinch. False when not tracking.
    @discardableResult
    public func click() -> Bool { model.click() }

    public func startCalibration() { model.startCalibration() }
    public func toggleRecording() { model.toggleRecording() }

    /// Full window content (own sidebar), for the standalone app.
    public func window() -> some View { RootView().environment(model) }

    /// One section's content, for hosts with their own sidebar.
    public func detail(for section: String) -> some View {
        SectionDetail(section: SidebarSection(rawValue: section) ?? .live).environment(model)
    }

    public func settings() -> some View { SettingsView().environment(model) }

    /// Module-specific menu bar items (no Open/Quit).
    public func menuItems() -> some View { MenuItems().environment(model) }
}

struct SectionDetail: View {
    let section: SidebarSection

    var body: some View {
        switch section {
        case .setup: SetupPage()
        case .live: LiveView()
        case .calibrate: CalibrationPage()
        case .recordings: RecordingsPage()
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
            .safeAreaInset(edge: .bottom) { SidebarStatus().padding(12) }
        } detail: {
            SectionDetail(section: model.section ?? .live)
        }
    }
}

/// Compact tracking status at the bottom of the sidebar.
private struct SidebarStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        VStack(alignment: .leading, spacing: 6) {
            row(engine.faceDetected ? "Tracking face" : "No face",
                engine.faceDetected ? .green : .orange)
            if engine.calibratedDisplayMissing {
                row("Calibrated display not connected", .orange)
            } else if let calibration = engine.calibration {
                row("Calibrated · \(calibration.quality)", .green)
            } else {
                row("Not calibrated", .secondary)
            }
            if model.isRecording {
                HStack(spacing: 6) {
                    RecordingIndicator()
                    Text("Recording")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}

struct MenuItems: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Toggle("Show Gaze Cursor", isOn: $model.showCursor)
            .disabled(!model.engine.isCalibrated)
        Toggle("Dwell to Click", isOn: $model.dwellClick)
            .keyboardShortcut("e", modifiers: [.control, .option, .command])
            .disabled(!model.engine.isCalibrated && !model.dwellClick)
        Button(model.isRecording ? "Stop Recording" : "Start Recording", action: model.toggleRecording)
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(!model.engine.isCalibrated)
        Button("Calibrate…", action: model.startCalibration)
            .disabled(!model.engine.canCalibrate)
    }
}
