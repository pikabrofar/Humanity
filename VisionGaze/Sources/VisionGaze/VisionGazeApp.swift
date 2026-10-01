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
                .frame(minWidth: 920, minHeight: 600)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Calibrate…", action: model.startCalibration)
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button(model.isRecording ? "Stop Recording" : "Start Recording", action: model.toggleRecording)
                    .disabled(!model.engine.isCalibrated)
            }
            CommandGroup(before: .toolbar) {
                ForEach(AppSection.allCases) { section in
                    Button(section.title) { model.section = section }
                        .keyboardShortcut(section.shortcut, modifiers: .command)
                }
                Divider()
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
        Group {
            switch model.section {
            case .live: LiveView()
            case .calibrate: CalibrationPage()
            case .recordings: RecordingsPage()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SegmentedTabs(selection: $model.section,
                              options: AppSection.allCases.map { (value: $0, label: $0.title) })
            }
            ToolbarItemGroup(placement: .primaryAction) {
                TrackingStatus()
                RecordButton()
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background(WindowConfigurator { window in
            // One continuous surface from the title bar down.
            window.backgroundColor = .textBackgroundColor
            window.titlebarSeparatorStyle = .none
        })
        #if DEBUG
        .task { await Showcase.run(model) }
        #endif
    }
}

/// Face and frame-rate status, shown in the toolbar.
private struct TrackingStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        let running = engine.cameraState == .running
        HStack(spacing: 7) {
            StatusDot(active: running && engine.faceDetected)
            Text(running ? (engine.faceDetected ? "Tracking" : "No face") : "Camera off")
            if running {
                Text("\(Int(engine.fps.rounded())) fps")
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .fixedSize()
    }
}

struct RecordButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: model.toggleRecording) {
            HStack(spacing: 7) {
                if let active = model.activeRecording {
                    RecordingIndicator()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Date().timeIntervalSince(active.startDate).clockString).monospacedDigit()
                    }
                } else {
                    Circle().fill(Theme.record).frame(width: 8, height: 8)
                    Text("Record")
                }
            }
        }
        .buttonStyle(QuietButtonStyle())
        .help("Start or stop recording (⌥⌘R, works from any app)")
        .disabled(!model.engine.isCalibrated)
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
