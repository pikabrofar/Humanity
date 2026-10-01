import GazeKit
import SwiftUI

struct LiveView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !engine.isCalibrated {
                    CalibrationBanner()
                } else if engine.calibratedDisplayMissing {
                    Label("Calibrated display not connected", systemImage: "display.trianglebadge.exclamationmark")
                        .foregroundStyle(.orange)
                }

                HStack(alignment: .top, spacing: 16) {
                    CameraCard()
                        .frame(minWidth: 380)
                    VStack(spacing: 16) {
                        EyesCard()
                        GazeMapCard()
                    }
                    .frame(width: 280)
                }

                ControlsCard()
            }
            .padding(20)
        }
        .navigationTitle("Live")
    }
}

private struct CalibrationBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "scope")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Calibrate to start tracking").font(.headline)
                Text("A 45-second calibration maps your eye movements to the screen.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
            Button("Calibrate…", action: model.startCalibration)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.engine.faceDetected)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.accentColor.opacity(0.25)))
    }
}

private struct CameraCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        ZStack {
            switch engine.cameraState {
            case .running:
                CameraPreview(session: engine.captureSession.session)
                LandmarkOverlay(landmarks: engine.landmarks, imageSize: engine.imageSize)
            case .starting:
                ProgressView("Starting camera…")
            case .denied:
                CameraMessage(
                    symbol: "video.slash",
                    title: "Camera access needed",
                    message: "OculOS processes video on-device only. Nothing leaves your Mac.",
                    action: ("Open Privacy Settings", {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                    })
                )
            case .failed(let message):
                CameraMessage(symbol: "exclamationmark.triangle", title: "Camera unavailable", message: message,
                              action: ("Retry", { Task { await engine.start() } }))
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            if engine.cameraState == .running {
                HStack(spacing: 6) {
                    StatusChip(text: String(format: "%.0f fps", engine.fps), symbol: "speedometer")
                    StatusChip(text: engine.faceDetected ? "Face" : "No face",
                               symbol: engine.faceDetected ? "face.smiling" : "face.dashed",
                               tint: engine.faceDetected ? .green : .orange)
                    if engine.features?.isBlinking == true {
                        StatusChip(text: "Blink", symbol: "eye.slash", tint: .yellow)
                    }
                }
                .padding(10)
            }
        }
    }
}

private struct CameraMessage: View {
    let symbol: String
    let title: String
    let message: String
    let action: (String, () -> Void)

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(action.0, action: action.1).padding(.top, 4)
        }
        .padding(30)
        .foregroundStyle(.white)
    }
}

/// Stylized eyes showing where each pupil sits within its eye, plus head pose.
private struct EyesCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let features = model.engine.features
        Card(title: "Eyes", symbol: "eye.circle") {
            HStack(spacing: 16) {
                // Mirrored so it reads like a mirror: the eye on the image's right is drawn on the left.
                EyeGlyph(eye: displayOrder[0], blinking: features?.isBlinking ?? false)
                EyeGlyph(eye: displayOrder[1], blinking: features?.isBlinking ?? false)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            if let f = features {
                Meter(label: "Openness", value: f.openness / 0.4, display: String(format: "%.2f", f.openness))
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        angle("Yaw", f.yaw)
                        angle("Pitch", f.pitch)
                        angle("Roll", f.roll)
                        if let model = self.model.engine.calibration?.model {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Distance").font(.caption2).foregroundStyle(.secondary)
                                Text(String(format: "%.0f cm", model.headPosition(f).z / 10)).font(.callout.monospacedDigit())
                            }
                        }
                    }
                }
                if let net = f.networkGaze {
                    Text(String(format: "CNN gaze  %+.0f°  %+.0f°", net.x * 180 / .pi, net.y * 180 / .pi))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Waiting for a face…").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var displayOrder: [EyeFeatures?] {
        guard let f = model.engine.features, let l = model.engine.landmarks else { return [nil, nil] }
        return l.leftEye.centroid.x > l.rightEye.centroid.x ? [f.left, f.right] : [f.right, f.left]
    }

    private func angle(_ label: String, _ radians: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%+.0f°", radians * 180 / .pi)).font(.callout.monospacedDigit())
        }
    }
}

private struct EyeGlyph: View {
    let eye: EyeFeatures?
    let blinking: Bool

    var body: some View {
        let width: CGFloat = 100, height: CGFloat = 46
        ZStack {
            EyeShape().fill(.background)
            if let eye, !blinking {
                Circle()
                    .fill(Color.accentColor.gradient)
                    .overlay(Circle().fill(.black).padding(6))
                    .frame(width: 22, height: 22)
                    // Mirror x; pupil.y is in eye-widths with y up.
                    .offset(x: (0.5 - eye.pupil.x) * width * 1.4, y: -eye.pupil.y * width * 1.4)
                    .animation(.linear(duration: 0.06), value: eye.pupil)
            }
            EyeShape().stroke(.secondary, lineWidth: 1.5)
            if blinking {
                Capsule().fill(.secondary).frame(width: width * 0.8, height: 2)
            }
        }
        .frame(width: width, height: height)
        .clipShape(EyeShape())
        .overlay(EyeShape().stroke(.secondary.opacity(0.6), lineWidth: 1.5))
    }
}

private struct EyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.45))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.45))
        return path
    }
}

/// Miniature of the target display with the live gaze point and a short trail.
private struct GazeMapCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        let screen = engine.targetScreen
        Card(title: "Gaze", symbol: "dot.viewfinder") {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(.primary.opacity(0.06)))
                context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 6), with: .color(.primary.opacity(0.15)))

                let points = engine.trail.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                for (i, p) in points.enumerated() {
                    let alpha = Double(i + 1) / Double(points.count) * 0.4
                    context.fill(Path(ellipseIn: CGRect(center: p, radius: 2.5)), with: .color(.accentColor.opacity(alpha)))
                }
                if let gaze = engine.gaze {
                    let p = CGPoint(x: gaze.x * size.width, y: gaze.y * size.height)
                    context.fill(Path(ellipseIn: CGRect(center: p, radius: 6)), with: .color(.accentColor))
                    context.stroke(Path(ellipseIn: CGRect(center: p, radius: 6)), with: .color(.white), lineWidth: 1.5)
                }
            }
            .aspectRatio(screen.frame.width / screen.frame.height, contentMode: .fit)

            HStack {
                Text(screen.localizedName).lineLimit(1)
                Spacer()
                if let gaze = engine.gaze {
                    Text("\(Int(gaze.x * screen.frame.width)), \(Int(gaze.y * screen.frame.height))")
                        .monospacedDigit()
                } else {
                    Text(engine.isCalibrated ? "—" : "Not calibrated")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct ControlsCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Card {
            HStack(spacing: 20) {
                Toggle(isOn: $model.showCursor) {
                    Label("Show gaze cursor", systemImage: "circle.circle")
                }
                .toggleStyle(.switch)

                Picker("Style", selection: $model.cursorStyle) {
                    ForEach(CursorStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .labelsHidden()

                Spacer()

                RecordButton()
            }
            .disabled(!model.engine.isCalibrated)
        }
    }
}

struct RecordButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: model.toggleRecording) {
            if let active = model.activeRecording {
                HStack(spacing: 8) {
                    RecordingIndicator()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("Stop  \(Date().timeIntervalSince(active.startDate).clockString)").monospacedDigit()
                    }
                }
            } else {
                Label("Record", systemImage: "record.circle")
            }
        }
        .controlSize(.large)
        .help("Start or stop recording (⌥⌘R, works from any app)")
        .disabled(!model.engine.isCalibrated)
    }
}
