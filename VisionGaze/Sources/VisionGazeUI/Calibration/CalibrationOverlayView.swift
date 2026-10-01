import GazeKit
import QuartzCore
import SwiftUI

/// Full-screen calibration UI, hosted in an `OverlayWindow`.
struct CalibrationOverlayView: View {
    let controller: CalibrationController
    let engine: GazeEngine

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                switch controller.phase {
                case .intro:
                    IntroCard(engine: engine, begin: controller.begin, cancel: controller.close)
                case .countdown(let n):
                    Text("\(n)")
                        .font(.system(size: 120, weight: .thin, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: n)
                    CalibrationDot(collecting: false)
                        .position(point(controller.dotPosition, in: geo.size))
                        .opacity(0.5)
                case .running, .validating:
                    CalibrationDot(collecting: controller.collecting)
                        .position(point(controller.dotPosition, in: geo.size))
                    if controller.retrying {
                        Text("Let's redo the points you missed")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                            .position(x: geo.size.width / 2, y: geo.size.height - 70)
                    } else if controller.phase == .validating {
                        Text("Checking accuracy")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                            .position(x: geo.size.width / 2, y: geo.size.height - 70)
                    }
                case .pursuit:
                    // Position from the same clock the samples are matched against.
                    TimelineView(.animation) { _ in
                        CalibrationDot(collecting: false)
                            .position(point(CalibrationController.pursuitPoint(CACurrentMediaTime() - controller.pursuitStart), in: geo.size))
                    }
                    Text("Follow the dot with your eyes")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                        .position(x: geo.size.width / 2, y: 60)
                case .headMotion:
                    CalibrationDot(collecting: false)
                        .position(point(controller.dotPosition, in: geo.size))
                    VStack(spacing: 6) {
                        Text("Keep looking at the dot")
                            .font(.title2.weight(.semibold))
                        Text("Slowly turn, tilt, and move your head around. \(controller.headMotionRemaining)")
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + 90)
                case .fitting:
                    ProgressView("Fitting model…")
                        .controlSize(.large)
                        .tint(.white)
                        .foregroundStyle(.white)
                case .results:
                    if let result = controller.result {
                        ResultsView(result: result, gaze: engine.gaze, size: geo.size,
                                    redo: controller.begin, done: controller.close)
                    }
                case .failed(let message):
                    FailureCard(message: message, retry: controller.begin, cancel: controller.close)
                }

                VStack {
                    if [.running, .pursuit, .headMotion, .validating].contains(controller.phase) || isCountdown {
                        if !engine.faceDetected {
                            Label("Face not detected — look at the screen", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(.orange.opacity(0.9), in: Capsule())
                                .foregroundStyle(.white)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    Spacer()
                    if controller.phase == .running || controller.phase == .validating {
                        ProgressDots(total: controller.progressTotal, current: controller.currentIndex)
                            .padding(.bottom, 28)
                    }
                }
                .padding(.top, 40)
                .animation(.easeInOut, value: engine.faceDetected)
            }
        }
        .ignoresSafeArea()
    }

    private var isCountdown: Bool {
        if case .countdown = controller.phase { return true }
        return false
    }

    private var background: some View {
        ZStack {
            Color(white: 0.07)
            RadialGradient(colors: [Color(white: 0.13), .clear], center: .center, startRadius: 0, endRadius: 900)
        }
    }

    private func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }
}

/// A fixation target: a contracting ring around a small dot. The contraction
/// draws the eye to the exact center while samples are collected.
private struct CalibrationDot: View {
    let collecting: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.85), lineWidth: 3)
                .frame(width: collecting ? 16 : 64, height: collecting ? 16 : 64)
                .animation(collecting ? .easeIn(duration: CalibrationController.minCollectTime) : .easeOut(duration: 0.25),
                           value: collecting)
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .shadow(color: .accentColor, radius: 6)
        }
        .frame(width: 80, height: 80)
    }
}

private struct ProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < current ? Color.accentColor : i == current ? .white : .white.opacity(0.2))
                    .frame(width: i == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
    }
}

private struct IntroCard: View {
    let engine: GazeEngine
    let begin: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "scope")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 8) {
                Text("Calibration").font(.largeTitle.weight(.semibold))
                Text("About 45 seconds: look at nine dots, follow a moving dot, hold your gaze while moving your head, then five dots to check accuracy.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                tip("face.smiling", "Sit about an arm's length from the screen")
                tip("hand.raised", "Keep your head still — move only your eyes")
                tip("lightbulb", "Light your face evenly, avoid bright light behind you")
            }
            .padding(.vertical, 4)

            Label(engine.faceDetected ? "Face detected" : "Looking for your face…",
                  systemImage: engine.faceDetected ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(engine.faceDetected ? .green : .orange)
                .font(.callout.weight(.medium))
                .animation(.default, value: engine.faceDetected)

            HStack(spacing: 12) {
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Begin", action: begin)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            Text("Space to begin · Esc to cancel at any time")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(36)
        .frame(width: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 22)
        }
    }
}

private struct FailureCard: View {
    let message: String
    let retry: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Calibration failed").font(.title2.weight(.semibold))
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack {
                Button("Close", action: cancel).keyboardShortcut(.cancelAction)
                Button("Try Again", action: retry).keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

/// Shows each target against the model's mean prediction, plus the live gaze
/// dot so the user can sanity-check the result before accepting it.
private struct ResultsView: View {
    let result: StoredCalibration
    let gaze: CGPoint?
    let size: CGSize
    let redo: () -> Void
    let done: () -> Void

    var body: some View {
        ZStack {
            Canvas { context, size in
                // Held-out validation points: an honest picture of accuracy.
                for point in result.validation?.points ?? result.model.report.points {
                    let target = scaled(point.target, size)
                    let predicted = scaled(point.predicted, size)
                    let color = color(for: point.error)

                    var line = Path()
                    line.move(to: target)
                    line.addLine(to: predicted)
                    context.stroke(line, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    context.stroke(Path(ellipseIn: CGRect(center: target, radius: 14)), with: .color(.white.opacity(0.5)), lineWidth: 1.5)
                    context.fill(Path(ellipseIn: CGRect(center: predicted, radius: 5)), with: .color(color))
                }
            }

            if let gaze {
                Circle()
                    .fill(Color.accentColor.opacity(0.35))
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 34, height: 34)
                    .position(scaled(gaze, size))
                    .allowsHitTesting(false)
            }

            VStack(spacing: 16) {
                Text(result.quality)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                HStack(spacing: 28) {
                    stat(String(format: "%.1f°", result.accuracyDegrees), "accuracy")
                    if let precision = result.validation?.precisionDegrees {
                        stat(String(format: "%.1f°", precision), "precision")
                    }
                    stat(String(format: "%.0f pt", result.errorPoints), "fit error")
                }
                Text("The blue circle follows your gaze. Look around to check it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Recalibrate", action: redo)
                    Button("Done", action: done)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .environment(\.colorScheme, .dark)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.monospacedDigit().weight(.medium))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func scaled(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    private func color(for error: Double) -> Color {
        let points = error * Double(size.width)
        return points < 40 ? .green : points < 90 ? .yellow : .red
    }
}

extension CGRect {
    init(center: CGPoint, radius: CGFloat) {
        self.init(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
