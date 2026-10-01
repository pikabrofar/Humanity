import SwiftUI

/// First-run quick setup: camera → calibration → try the cursor.
/// Also reachable from the sidebar at any time.
struct SetupPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let engine = model.engine
        let cameraOK = engine.cameraState == .running
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Setup").font(.largeTitle.weight(.semibold))
                    Text("About a minute. Camera video is processed on this Mac and never leaves it.")
                        .foregroundStyle(.secondary)
                }

                StepCard(number: 1, title: "Camera", done: cameraOK,
                         detail: "OculOS watches your eyes through the camera. Sit about an arm's length away, with light on your face.") {
                    if engine.cameraState == .denied {
                        Button("Open Camera Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                        }
                    } else if cameraOK {
                        Label(engine.faceDetected ? "Face detected" : "Looking for your face…",
                              systemImage: engine.faceDetected ? "face.smiling" : "face.dashed")
                            .foregroundStyle(engine.faceDetected ? .green : .orange)
                    }
                }

                StepCard(number: 2, title: "Calibrate", done: engine.isCalibrated,
                         detail: "Follow dots for about 45 seconds so OculOS can map your eye position to the screen.") {
                    HStack {
                        Button(engine.isCalibrated ? "Recalibrate" : "Start Calibration", action: model.startCalibration)
                            .buttonStyle(.borderedProminent)
                            .disabled(!engine.faceDetected)
                        if let calibration = engine.calibration {
                            Text(String(format: "%@ · %.1f° accuracy", calibration.quality, calibration.accuracyDegrees))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if engine.networkName != nil {
                        Label("Gaze CNN active: \(engine.networkName ?? "")", systemImage: "brain")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                StepCard(number: 3, title: "Try it", done: model.showCursor,
                         detail: "Turn on the gaze cursor. It holds still while you look at something and jumps when your eyes move. Your clicks can also be used to adjust the calibration.") {
                    Toggle("Show gaze cursor", isOn: $model.showCursor)
                        .toggleStyle(.switch)
                        .disabled(!engine.isCalibrated)
                }

                HStack {
                    Spacer()
                    Button {
                        Defaults.set(true, .completedSetup)
                        model.section = .live
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!engine.isCalibrated)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Quick Setup")
    }
}

private struct StepCard<Content: View>: View {
    let number: Int
    let title: String
    let done: Bool
    let detail: String
    @ViewBuilder var content: Content

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(done ? Color.green : Color.accentColor.opacity(0.15))
                    if done {
                        Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                    } else {
                        Text("\(number)").font(.headline).foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.headline)
                    Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    content
                }
                Spacer(minLength: 0)
            }
        }
        .animation(.default, value: done)
    }
}
