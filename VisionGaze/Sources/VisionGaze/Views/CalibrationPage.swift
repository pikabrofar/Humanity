import GazeKit
import SwiftUI

struct CalibrationPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calibration")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Teaches VisionGaze how your eyes map to the screen. About 45 seconds.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                CalibrationSteps()
                    .padding(.top, 32)

                HStack(spacing: 14) {
                    Button("Start Calibration", action: model.startCalibration)
                        .buttonStyle(PrimaryButtonStyle(large: true))
                        .disabled(model.engine.cameraState != .running)
                    if NSScreen.screens.count > 1 {
                        Picker("Display", selection: $model.calibrationDisplayID) {
                            ForEach(NSScreen.screens, id: \.displayID) { screen in
                                Text(screen.localizedName).tag(screen.displayID)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Text("⇧⌘K")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 28)

                if let calibration = model.engine.calibration {
                    CurrentCalibration(calibration: calibration)
                        .padding(.top, 52)
                }

                Tips()
                    .padding(.top, 52)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
    }
}

/// The four calibration steps as a numbered row. Shared with the full-screen intro.
struct CalibrationSteps: View {
    private static let steps = [
        ("Grid", "Look at nine dots as they appear."),
        ("Pursuit", "Follow a moving dot with your eyes."),
        ("Head", "Hold your gaze and move your head."),
        ("Check", "Five more dots measure accuracy."),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach(Self.steps.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(format: "%02d", i + 1))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Text(Self.steps[i].0)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 4)
                    Text(Self.steps[i].1)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }
}

private struct CurrentCalibration: View {
    @Environment(AppModel.self) private var model
    let calibration: StoredCalibration

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Eyebrow("Current calibration")
                Spacer()
                Button("Clear", action: model.clearCalibration)
                    .buttonStyle(QuietButtonStyle())
            }

            HStack(alignment: .top, spacing: 36) {
                // Held-out validation points when available: an honest picture of accuracy.
                ErrorPlot(points: calibration.validation?.points ?? calibration.model.report.points,
                          aspect: calibration.screenSize.width / calibration.screenSize.height)
                    .frame(width: 240)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 32) {
                        Readout(label: calibration.validation == nil ? "Fit error" : "Accuracy",
                                value: String(format: "%.1f°", calibration.accuracyDegrees), font: .figure)
                        if let precision = calibration.validation?.precisionDegrees {
                            Readout(label: "Precision", value: String(format: "%.1f°", precision), font: .figure)
                        }
                        Readout(label: "Quality", value: calibration.quality, font: .figure)
                    }
                    Text("\(calibration.displayName) · \(calibration.model.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            DetailsTable(rows: details)

            Text("Head movement is compensated. Recalibrate after moving the camera or switching displays.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var details: [(String, String)] {
        let m = calibration.model
        let offsetMM = (m.cameraPosition - 0.5) * m.geometry.widthMM
        let weights = m.headRotationWeights
        var rows = [
            ("Camera", String(format: "%.0f mm above screen, %.0f mm %@ of center",
                              m.cameraGapMM, abs(offsetMM), offsetMM < 0 ? "left" : "right")),
            ("Screen", String(format: "%.0f × %.0f mm", m.geometry.widthMM, m.geometry.heightMM)),
            ("Your distance", String(format: "%.0f cm", m.calibrationDistanceMM / 10)),
            ("Head weights", String(format: "yaw %+.2f · pitch %+.2f", weights.yaw, weights.pitch)),
            ("Eye appearance model", m.appearanceRidge.map { String(format: "On (ridge %g)", $0) } ?? "Off"),
        ]
        if !calibration.clickSamples.isEmpty {
            rows.append(("Learned from clicks", "\(calibration.clickSamples.count) samples"))
        }
        return rows
    }
}

/// Label/value rows separated by hairlines.
private struct DetailsTable: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            ForEach(rows.indices, id: \.self) { i in
                HStack {
                    Text(rows[i].0).foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                    Text(rows[i].1).monospacedDigit()
                }
                .font(.system(size: 12.5))
                .padding(.vertical, 9)
                Hairline()
            }
        }
    }
}

/// Targets (rings) against mean predictions (dots) for each calibration point.
private struct ErrorPlot: View {
    let points: [CalibrationReport.Point]
    let aspect: CGFloat

    var body: some View {
        Canvas { context, size in
            let frame = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), cornerRadius: 8)
            context.fill(frame, with: .color(Theme.wash))
            context.stroke(frame, with: .color(Theme.hairline), lineWidth: 1)
            for point in points {
                let t = CGPoint(x: point.target.x * size.width, y: point.target.y * size.height)
                let p = CGPoint(x: point.predicted.x * size.width, y: point.predicted.y * size.height)
                var line = Path()
                line.move(to: t)
                line.addLine(to: p)
                context.stroke(line, with: .color(.secondary), lineWidth: 1)
                context.stroke(Path(ellipseIn: CGRect(center: t, radius: 5)), with: .color(.secondary), lineWidth: 1)
                context.fill(Path(ellipseIn: CGRect(center: p, radius: 2.5)), with: .color(Theme.signal))
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
    }
}

private struct Tips: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow("Tips")
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 16) {
                GridRow {
                    tip("Distance", "Sit 50–70 cm away, centered on the camera.")
                    tip("Light", "Light your face evenly. Avoid a bright window behind you.")
                }
                GridRow {
                    tip("Stillness", "Keep your head still unless the step asks you to move it.")
                    tip("Glasses", "Fine to wear, but reflections cost some accuracy.")
                }
            }
        }
    }

    private func tip(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 12.5, weight: .semibold))
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
