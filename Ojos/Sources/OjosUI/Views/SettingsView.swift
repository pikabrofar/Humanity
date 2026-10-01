import AVFoundation
import ApplicationServices
import GazeKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        @Bindable var engine = model.engine
        Form {
            Section("Camera") {
                Picker("Camera", selection: $engine.cameraID) {
                    Text("System Default").tag(String?.none)
                    ForEach(CameraCapture.videoDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(String?.some(device.uniqueID))
                    }
                }
                Toggle(isOn: $engine.pupilRefinement) {
                    Text("Image-based pupil refinement")
                    Text("Locates the dark pupil blob in each eye instead of relying only on Vision's landmark. Steadier in good light.")
                }
            }

            Section("Gaze CNN (Core ML)") {
                LabeledContent("Model") {
                    if let name = engine.networkName {
                        Text(name)
                    } else {
                        Text("None").foregroundStyle(.secondary)
                    }
                }
                if let error = engine.networkError {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
                if engine.calibrationNeedsNetworkRefresh {
                    Label("Recalibrate: the CNN changed since the last calibration.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                HStack {
                    Button("Load Model…") { chooseModel() }
                    if engine.networkName != nil {
                        Button("Remove", role: .destructive) { engine.removeNetwork() }
                    }
                }
                Text("Optional: load your own appearance-based gaze model (Core ML), run on the face each frame and combined with the eye and head features during calibration. Make sure its weights are licensed for your use; most public gaze models are research-only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Smoothing") {
                LabeledSlider(title: "Fixation radius", value: $engine.stability,
                              low: "Precise", high: "Steady")
                LabeledSlider(title: "Jump speed", value: $engine.responsiveness,
                              low: "Cautious", high: "Snappy")
            }

            Section("Accuracy") {
                Toggle(isOn: $model.learnFromClicks) {
                    Text("Learn from clicks")
                    Text("You usually look where you click, so each click is added as a calibration sample. This can reduce drift but may not always help.")
                }
                if let clicks = model.engine.calibration?.clickSamples.count, clicks > 0 {
                    LabeledContent("Learned samples", value: "\(clicks)")
                }
            }

            Section("Clicking") {
                Toggle(isOn: $model.dwellClick) {
                    Text("Dwell to click")
                    Text("Clicks after you look at one spot; a ring shows the progress. Esc cancels a click in progress, ⌃⌥⌘E turns dwell on or off. Off at every launch, and off, gaze never clicks by itself. Dwell skips close buttons, sheets and alerts.")
                }
                if model.dwellClick {
                    Slider(value: $model.dwellTime, in: 0.3...3, step: 0.1) {
                        Text("Dwell time \(model.dwellTime, specifier: "%.1f") s")
                    }
                }
                Toggle(isOn: $model.snapToTargets) {
                    Text("Snap to buttons and links")
                    Text("Clicks the nearest control within about 4° of your gaze (1.5° for dwell).")
                }
                Text("Press ⌃⌥⌘G to click where you look.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !AXIsProcessTrusted() {
                    HStack {
                        Label("Clicking needs Accessibility permission.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Grant…") {
                            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }

            Section("Gaze Cursor") {
                Picker("Style", selection: $model.cursorStyle) {
                    ForEach(CursorStyle.allCases) { Text($0.label).tag($0) }
                }
                Slider(value: $model.cursorSize, in: 20...120) { Text("Size") }
            }

            Section("Recording") {
                Toggle(isOn: $model.hideWhileRecording) {
                    Text("Hide ojoS windows when a recording starts")
                    Text("Keeps them out of the way and out of the heatmap screenshot. The menu bar icon stays visible; stop with ⌥⌘R or from the menu bar.")
                }
                Toggle(isOn: $model.captureScreenshot) {
                    Text("Capture screenshot as heatmap background")
                    Text("Requires Screen Recording permission. Screenshots stay on this Mac.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension SettingsView {
    private func chooseModel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "mlpackage"), .init(filenameExtension: "mlmodel"),
                                     .init(filenameExtension: "mlmodelc")].compactMap { $0 }
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.engine.installNetwork(from: url) }
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let low: String
    let high: String

    var body: some View {
        LabeledContent(title) {
            VStack(spacing: 2) {
                Slider(value: $value, in: 0...1)
                HStack {
                    Text(low)
                    Spacer()
                    Text(high)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}
