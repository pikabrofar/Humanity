import AppKit
import SwiftUI

@main
struct VisionGazeApp: App {
    @State private var model = AppModel()

    init() {
        // Allows `swift run` without an app bundle to show a regular window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("VisionGaze", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Calibrate…", action: model.startCalibration)
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button(model.isRecording ? "Stop Recording" : "Start Recording", action: model.toggleRecording)
                    .disabled(!model.engine.isCalibrated)
            }
            CommandGroup(after: .toolbar) {
                Toggle("Show Gaze Cursor", isOn: Bindable(model).showCursor)
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(!model.engine.isCalibrated)
            }
        }

        Settings {
            SettingsView().environment(model)
        }

        MenuBarExtra {
            MenuBarContent().environment(model)
        } label: {
            Image(systemName: model.isRecording ? "record.circle.fill" : "eye")
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
            switch model.section ?? .live {
            case .setup: SetupPage()
            case .live: LiveView()
            case .calibrate: CalibrationPage()
            case .recordings: RecordingsPage()
            }
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
            if let calibration = engine.calibration {
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

private struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        Toggle("Show Gaze Cursor", isOn: $model.showCursor)
            .disabled(!model.engine.isCalibrated)
        Button(model.isRecording ? "Stop Recording" : "Start Recording", action: model.toggleRecording)
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(!model.engine.isCalibrated)
        Button("Calibrate…", action: model.startCalibration)
        Divider()
        Button("Open VisionGaze") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit VisionGaze") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
