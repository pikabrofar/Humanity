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
                Color(white: 0.04)

                switch controller.phase {
                case .intro:
                    Intro(engine: engine, begin: controller.begin, cancel: controller.close)
                case .countdown(let n):
                    Text("\(n)")
                        .font(.system(size: 96, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: n)
                        .offset(y: -120)
                    CalibrationDot(collecting: false)
                        .position(point(controller.dotPosition, in: geo.size))
                        .opacity(0.5)
                case .running, .validating:
                    CalibrationDot(collecting: controller.collecting)
                        .position(point(controller.dotPosition, in: geo.size))
                    if controller.retrying {
                        Caption("Let's redo the points you missed")
                            .position(x: geo.size.width / 2, y: geo.size.height - 76)
                    } else if controller.phase == .validating {
                        Caption("Checking accuracy")
                            .position(x: geo.size.width / 2, y: geo.size.height - 76)
                    }
                case .pursuit:
                    // Position from the same clock the samples are matched against.
                    TimelineView(.animation) { _ in
                        CalibrationDot(collecting: false)
                            .position(point(CalibrationController.pursuitPoint(CACurrentMediaTime() - controller.pursuitStart), in: geo.size))
                    }
                    Caption("Follow the dot with your eyes")
                        .position(x: geo.size.width / 2, y: 64)
                case .headMotion:
                    CalibrationDot(collecting: false)
                        .position(point(controller.dotPosition, in: geo.size))
                    VStack(spacing: 8) {
                        Text("Keep looking at the dot")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Slowly turn, tilt and move your head")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(controller.headMotionRemaining)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.signal)
                            .padding(.top, 4)
                    }
                    .foregroundStyle(.white)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + 110)
                case .fitting:
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.small)
                        Caption("Fitting your model")
                    }
                case .results:
                    if let result = controller.result {
                        ResultsView(result: result, gaze: engine.gaze, size: geo.size,
                                    redo: controller.begin, done: controller.close)
                    }
                case .failed(let message):
                    Panel {
                        VStack(spacing: 10) {
                            Text("Calibration failed").font(.system(size: 22, weight: .semibold))
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        HStack(spacing: 10) {
                            Button("Close", action: controller.close)
                                .buttonStyle(QuietButtonStyle())
                                .keyboardShortcut(.cancelAction)
                            Button("Try Again", action: controller.begin)
                                .buttonStyle(PrimaryButtonStyle(large: true))
                                .keyboardShortcut(.defaultAction)
                        }
                    }
                    .frame(width: 400)
                }

                VStack {
                    if [.running, .pursuit, .headMotion, .validating].contains(controller.phase) || isCountdown,
                       !engine.faceDetected {
                        HStack(spacing: 8) {
                            Circle().fill(Theme.signal).frame(width: 6, height: 6)
                            Text("Face not detected. Look at the screen.")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Capsule().fill(.white.opacity(0.08)))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                    if controller.phase == .running || controller.phase == .validating {
                        ProgressDots(total: controller.progressTotal, current: controller.currentIndex)
                            .padding(.bottom, 32)
                    }
                }
                .padding(.top, 40)
                .animation(.easeInOut, value: engine.faceDetected)
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private var isCountdown: Bool {
        if case .countdown = controller.phase { return true }
        return false
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
                .stroke(Theme.signal, lineWidth: 2.5)
                .frame(width: collecting ? 14 : 56, height: collecting ? 14 : 56)
                .animation(collecting ? .easeIn(duration: CalibrationController.minCollectTime) : .easeOut(duration: 0.25),
                           value: collecting)
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .shadow(color: Theme.signal.opacity(0.8), radius: 6)
        }
        .frame(width: 80, height: 80)
    }
}

private struct ProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < current ? Color.white.opacity(0.8) : i == current ? Theme.signal : .white.opacity(0.16))
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.snappy, value: current)
    }
}

private struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.55))
    }
}

/// Dark rounded panel used for results and errors.
private struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 24) { content }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.09).opacity(0.94)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }
}

private struct Intro: View {
    let engine: GazeEngine
    let begin: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Eyebrow("Calibration")
            Text("Follow the dots with your eyes")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 14)
            Text("About 45 seconds. Keep your head still unless a step asks you to move it.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 10)

            CalibrationSteps()
                .multilineTextAlignment(.leading)
                .frame(width: 660)
                .padding(.top, 44)

            HStack(spacing: 8) {
                StatusDot(active: engine.faceDetected)
                Text(engine.faceDetected ? "Face detected" : "Looking for your face…")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .animation(.default, value: engine.faceDetected)
            .padding(.top, 44)

            HStack(spacing: 10) {
                Button("Cancel", action: cancel)
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Begin", action: begin)
                    .buttonStyle(PrimaryButtonStyle(large: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 22)

            Text("Space to begin · Esc to cancel at any time")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 16)
        }
        .multilineTextAlignment(.center)
    }
}

/// Shows each target against the model's mean prediction, plus the live gaze
/// ring so the user can sanity-check the result before accepting it.
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
                    context.stroke(line, with: .color(color.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    context.stroke(Path(ellipseIn: CGRect(center: target, radius: 12)), with: .color(.white.opacity(0.35)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(center: predicted, radius: 4)), with: .color(color))
                }
            }

            Panel {
                VStack(spacing: 6) {
                    Eyebrow("Calibration complete")
                    Text(result.quality)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 36) {
                    stat(String(format: "%.1f°", result.accuracyDegrees), "Accuracy")
                    if let precision = result.validation?.precisionDegrees {
                        stat(String(format: "%.1f°", precision), "Precision")
                    }
                    stat(String(format: "%.0f pt", result.errorPoints), "Fit error")
                }
                Text("The orange ring follows your gaze. Look around to check it.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 10) {
                    Button("Recalibrate", action: redo)
                        .buttonStyle(QuietButtonStyle())
                    Button("Done", action: done)
                        .buttonStyle(PrimaryButtonStyle(large: true))
                        .keyboardShortcut(.defaultAction)
                }
            }

            // Above the panel, so gaze can be checked everywhere.
            if let gaze {
                Circle()
                    .strokeBorder(Theme.signal, lineWidth: 2)
                    .background(Circle().fill(Theme.signal.opacity(0.15)))
                    .frame(width: 32, height: 32)
                    .position(scaled(gaze, size))
                    .allowsHitTesting(false)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.figure).foregroundStyle(.white)
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
        }
    }

    private func scaled(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    /// Small misses read white, moderate ones orange, large ones red.
    private func color(for error: Double) -> Color {
        let points = error * Double(size.width)
        return points < 40 ? .white : points < 90 ? Theme.signal : Theme.record
    }
}

extension CGRect {
    init(center: CGPoint, radius: CGFloat) {
        self.init(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
