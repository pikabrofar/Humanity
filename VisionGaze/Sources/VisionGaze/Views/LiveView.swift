import GazeKit
import SwiftUI

struct LiveView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            Viewport()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Inspector()
                .frame(width: 232)
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: Viewport

/// The camera feed with landmarks, a status line, and the cursor controls.
private struct Viewport: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        let running = engine.cameraState == .running
        ZStack {
            Theme.viewport
            switch engine.cameraState {
            case .running:
                CameraPreview(session: engine.captureSession.session)
                LandmarkOverlay(landmarks: engine.landmarks, imageSize: engine.imageSize)
            case .starting:
                ProgressView().controlSize(.small)
            case .denied:
                ViewportMessage(
                    title: "Camera access needed",
                    message: "Video is processed on this Mac and never leaves it.",
                    action: ("Open Privacy Settings", {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                    })
                )
            case .failed(let message):
                ViewportMessage(title: "Camera unavailable", message: message,
                                action: ("Try Again", { Task { await engine.start() } }))
            }
        }
        .overlay(alignment: .top) {
            if running { ViewportStatus() }
        }
        .overlay(alignment: .bottom) {
            if running { CursorBar().padding(16) }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        // Defines the edge against the dark canvas in dark mode.
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(.white.opacity(0.07)))
        .environment(\.colorScheme, .dark)
    }
}

/// One line of monospaced status text over a soft scrim.
private struct ViewportStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        let blinking = engine.features?.isBlinking == true
        HStack {
            HStack(spacing: 7) {
                StatusDot(active: engine.faceDetected && !blinking)
                Text(!engine.faceDetected ? "NO FACE" : blinking ? "BLINK" : "TRACKING")
            }
            Spacer()
            Text("\(Int(engine.fps.rounded())) FPS")
        }
        .font(.hud)
        .tracking(0.6)
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 30)
        .background(LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }
}

/// Floating capsule over the feed: the gaze cursor switch and style, or a
/// prompt to calibrate first.
private struct CursorBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 14) {
            if model.engine.isCalibrated {
                Toggle("Gaze cursor", isOn: $model.showCursor)
                    .toggleStyle(SignalSwitchStyle())
                Rectangle().fill(.white.opacity(0.16)).frame(width: 1, height: 14)
                InlinePicker(selection: $model.cursorStyle,
                             options: CursorStyle.allCases.map { (value: $0, label: $0.label) })
                    .padding(.trailing, 4)
            } else {
                Text("Calibrate to see your gaze on screen")
                    .foregroundStyle(.white.opacity(0.7))
                Button("Calibrate", action: model.startCalibration)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!model.engine.faceDetected)
            }
        }
        .font(.system(size: 12.5, weight: .medium))
        .padding(.leading, 18)
        .padding(.trailing, model.engine.isCalibrated ? 14 : 6)
        .frame(height: 40)
        .background(Capsule().fill(.black.opacity(0.6)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
    }
}

private struct ViewportMessage: View {
    let title: String
    let message: String
    let action: (String, () -> Void)

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action.0, action: action.1)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 10)
        }
        .padding(32)
    }
}

// MARK: Inspector

/// Live readouts: where you're looking, head pose, and the eyes themselves.
private struct Inspector: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GazeSection()
                Hairline()
                HeadSection()
                Hairline()
                EyesSection()
            }
            .padding(.top, 2)
        }
        .scrollIndicators(.never)
    }
}

private struct GazeSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        let screen = engine.currentScreen
        let size = screen?.frame.size ?? CGSize(width: 16, height: 10)
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Gaze")
            GazeMap(gaze: engine.gaze, trail: engine.trail, calibrated: engine.isCalibrated)
                .aspectRatio(size.width / size.height, contentMode: .fit)
            if engine.isCalibrated {
                HStack {
                    Text(engine.gaze.map { "\(Int($0.x * size.width)), \(Int($0.y * size.height))" } ?? "—")
                        .monospacedDigit()
                    Spacer()
                    Text(screen?.localizedName ?? "").lineLimit(1).foregroundStyle(.tertiary)
                }
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            } else {
                Button("Calibrate", action: model.startCalibration)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(engine.cameraState != .running)
            }
        }
    }
}

/// Miniature of the target display with the live gaze point and a short trail.
private struct GazeMap: View {
    let gaze: CGPoint?
    let trail: [CGPoint]
    let calibrated: Bool

    var body: some View {
        Canvas { context, size in
            let frame = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), cornerRadius: 8)
            context.fill(frame, with: .color(Theme.wash))
            context.stroke(frame, with: .color(Theme.hairline),
                           style: StrokeStyle(lineWidth: 1, dash: calibrated ? [] : [3, 3]))
            guard calibrated else {
                context.draw(Text("Not calibrated").font(.system(size: 11)).foregroundColor(.secondary),
                             at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }
            for (i, p) in trail.enumerated() {
                let alpha = Double(i + 1) / Double(trail.count) * 0.35
                let point = CGPoint(x: p.x * size.width, y: p.y * size.height)
                context.fill(Path(ellipseIn: CGRect(center: point, radius: 2)), with: .color(Theme.signal.opacity(alpha)))
            }
            if let gaze {
                let point = CGPoint(x: gaze.x * size.width, y: gaze.y * size.height)
                context.fill(Path(ellipseIn: CGRect(center: point, radius: 5)), with: .color(Theme.signal))
                context.stroke(Path(ellipseIn: CGRect(center: point, radius: 9)), with: .color(Theme.signal.opacity(0.35)), lineWidth: 1)
            }
        }
    }
}

private struct HeadSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let f = model.engine.features
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Head")
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
                GridRow {
                    Readout(label: "Yaw", value: degrees(f?.yaw))
                    Readout(label: "Pitch", value: degrees(f?.pitch))
                }
                GridRow {
                    Readout(label: "Roll", value: degrees(f?.roll))
                    Readout(label: "Distance", value: distance(f))
                }
            }
        }
    }

    private func degrees(_ radians: Double?) -> String {
        radians.map { String(format: "%+.0f°", $0 * 180 / .pi) } ?? "—"
    }

    private func distance(_ f: GazeFeatures?) -> String {
        guard let f, let calibration = model.engine.calibration else { return "—" }
        return String(format: "%.0f cm", calibration.model.headPosition(f).z / 10)
    }
}

private struct EyesSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let features = model.engine.features
        let blinking = features?.isBlinking ?? false
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Eyes")
            HStack(spacing: 12) {
                // Drawn like a mirror: the eye on the image's right appears on the left.
                EyeGlyph(eye: displayOrder[0], blinking: blinking)
                EyeGlyph(eye: displayOrder[1], blinking: blinking)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Openness").foregroundStyle(.secondary)
                    Spacer()
                    Text(features.map { String(format: "%.2f", $0.openness) } ?? "—").monospacedDigit()
                }
                .font(.system(size: 11.5))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.wash)
                        Capsule().fill(Theme.signal)
                            .frame(width: geo.size.width * min(max((features?.openness ?? 0) / 0.4, 0), 1))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private var displayOrder: [EyeFeatures?] {
        guard let f = model.engine.features, let l = model.engine.landmarks else { return [nil, nil] }
        return l.leftEye.centroid.x > l.rightEye.centroid.x ? [f.left, f.right] : [f.right, f.left]
    }
}

/// Outline of an eye with the iris placed where the pupil was measured.
private struct EyeGlyph: View {
    let eye: EyeFeatures?
    let blinking: Bool

    var body: some View {
        let width: CGFloat = 100, height: CGFloat = 40
        ZStack {
            EyeShape().fill(Theme.wash)
            if let eye, !blinking {
                // Iris in the signal color, like the app icon.
                Circle()
                    .fill(Theme.signal)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().fill(Color(white: 0.08)).frame(width: 6.5, height: 6.5))
                    .overlay(alignment: .topLeading) {
                        Circle().fill(.white).frame(width: 3, height: 3).offset(x: 4.5, y: 4)
                    }
                    // Mirror x; pupil.y is in eye-widths with y up.
                    .offset(x: (0.5 - eye.pupil.x) * width * 1.4, y: -eye.pupil.y * width * 1.4)
                    .animation(.linear(duration: 0.06), value: eye.pupil)
            }
            if blinking {
                Capsule().fill(.secondary).frame(width: width * 0.7, height: 1.5)
            }
        }
        .frame(width: width, height: height)
        .clipShape(EyeShape())
        .overlay(EyeShape().stroke(Color.primary.opacity(0.3), lineWidth: 1))
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
