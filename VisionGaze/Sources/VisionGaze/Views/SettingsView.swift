import AVFoundation
import GazeKit
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general, tracking, cursor
}

struct SettingsView: View {
    @AppStorage("settingsTab") private var tab = SettingsTab.general

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            TrackingSettings()
                .tabItem { Label("Tracking", systemImage: "eye") }
                .tag(SettingsTab.tracking)
            CursorSettings()
                .tabItem { Label("Cursor", systemImage: "circle.circle") }
                .tag(SettingsTab.cursor)
        }
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        @Bindable var engine = model.engine
        Form {
            Section {
                Picker("Camera", selection: $engine.cameraID) {
                    Text("System Default").tag(String?.none)
                    ForEach(CameraCapture.videoDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(String?.some(device.uniqueID))
                    }
                }
            } footer: {
                Text("Video is processed on this Mac. Frames are never saved or sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Recording") {
                Toggle(isOn: $model.hideWhileRecording) {
                    Text("Hide VisionGaze while recording")
                    Text("Stop with ⌥⌘R or from the menu bar.")
                }
                Toggle(isOn: $model.captureScreenshot) {
                    Text("Capture screenshot as heatmap background")
                    Text("Needs Screen Recording permission. Screenshots stay on this Mac.")
                }
            }
        }
        .settingsPane()
    }
}

private struct TrackingSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        @Bindable var engine = model.engine
        Form {
            Section("Smoothing") {
                LabeledSlider(title: "Fixation radius", value: $engine.stability, low: "Precise", high: "Steady")
                LabeledSlider(title: "Jump speed", value: $engine.responsiveness, low: "Cautious", high: "Snappy")
            }

            Section("Accuracy") {
                Toggle(isOn: $engine.pupilRefinement) {
                    Text("Image-based pupil refinement")
                    Text("Finds the dark pupil in each eye instead of relying only on Vision's landmark. Steadier in good light.")
                }
                Toggle(isOn: $model.learnFromClicks) {
                    Text("Learn from clicks")
                    Text("You look where you click, so each click refines the calibration.")
                }
                if let clicks = engine.calibration?.clickSamples.count, clicks > 0 {
                    LabeledContent("Learned samples", value: clicks.formatted())
                }
            }

            Section {
                LabeledContent("Model") {
                    Text(engine.networkName ?? "None")
                        .foregroundStyle(engine.networkName == nil ? .secondary : .primary)
                }
                if let error = engine.networkError {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
                if engine.calibrationNeedsNetworkRefresh {
                    Text("The model changed since the last calibration. Recalibrate to use it.")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                HStack {
                    Button("Load Model…") { chooseModel() }
                    if engine.networkName != nil {
                        Button("Remove", role: .destructive) { engine.removeNetwork() }
                    }
                }
            } header: {
                Text("Gaze model (Core ML)")
            } footer: {
                Text("Optional appearance-based network such as L2CS-Net, combined with the eye and head features during calibration. Build one with `make cnn-model`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
    }

    private func chooseModel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "mlpackage"), .init(filenameExtension: "mlmodel"),
                                     .init(filenameExtension: "mlmodelc")].compactMap { $0 }
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.engine.installNetwork(from: url) }
    }
}

private struct CursorSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                CursorPreview(style: model.cursorStyle, size: model.cursorSize)
                    .frame(height: 150)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                Picker("Style", selection: $model.cursorStyle) {
                    ForEach(CursorStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Size") {
                    HStack(spacing: 10) {
                        Slider(value: $model.cursorSize, in: 20...120)
                        Text("\(Int(model.cursorSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            } footer: {
                Text("Toggle the cursor from any app with ⇧⌘G.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
    }
}

/// The gaze cursor over a stylized page, so style and size can be judged.
private struct CursorPreview: View {
    let style: CursorStyle
    let size: Double
    private static let lines: [CGFloat] = [220, 300, 260, 280, 180, 240]

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.canvas)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Self.lines.indices, id: \.self) { i in
                    Capsule().fill(Color.primary.opacity(0.1))
                        .frame(width: Self.lines[i], height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 28)
            if style == .spotlight {
                SpotlightMask(center: CGPoint(x: 0.55, y: 0.5), size: size)
            } else {
                CursorMark(style: style, size: size)
            }
        }
        .clipped()
        .animation(.snappy(duration: 0.2), value: size)
    }
}

private extension View {
    func settingsPane() -> some View {
        formStyle(.grouped)
            .frame(width: 500)
            .fixedSize(horizontal: false, vertical: true)
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
