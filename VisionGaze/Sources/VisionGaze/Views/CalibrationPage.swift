import GazeKit
import SwiftUI

struct CalibrationPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    HStack(alignment: .top, spacing: 24) {
                        GridIllustration()
                            .frame(width: 180, height: 112)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Calibration").font(.title2.weight(.semibold))
                            Text("Four steps, about 45 seconds: a 3×3 grid of dots, a moving dot to follow, a head-movement step, and five held-out dots that measure accuracy.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 12) {
                                Picker("Display", selection: $model.calibrationDisplayID) {
                                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                                        Text(screen.localizedName).tag(screen.displayID)
                                    }
                                }
                                .frame(maxWidth: 260)
                                Button {
                                    model.startCalibration()
                                } label: {
                                    Label("Start Calibration", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(model.engine.cameraState != .running)
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                Card(title: "Tips for accuracy", symbol: "lightbulb") {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                        GridRow {
                            tip("ruler", "Sit 50–70 cm from the screen, centered on the camera.")
                            tip("sun.max", "Even, front-facing light. Avoid a window behind you.")
                        }
                        GridRow {
                            tip("figure.stand", "Keep your head still during and after calibration.")
                            tip("eyeglasses", "Glasses are fine, but reflections reduce accuracy.")
                        }
                    }
                    .font(.callout)
                }

                if let calibration = model.engine.calibration {
                    CurrentCalibrationCard(calibration: calibration)
                }
            }
            .padding(20)
        }
        .navigationTitle("Calibrate")
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CurrentCalibrationCard: View {
    @Environment(AppModel.self) private var model
    let calibration: StoredCalibration

    var body: some View {
        Card(title: "Current calibration", symbol: "checkmark.seal") {
            HStack(alignment: .top, spacing: 24) {
                ErrorPlot(report: calibration.model.report, aspect: calibration.screenSize.width / calibration.screenSize.height)
                    .frame(width: 260)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 28) {
                        stat(calibration.quality, "quality")
                        stat(String(format: "%.1f°", calibration.accuracyDegrees), calibration.validation == nil ? "fit error" : "accuracy")
                        if let precision = calibration.validation?.precisionDegrees {
                            stat(String(format: "%.1f°", precision), "precision")
                        }
                    }
                    Text("\(calibration.displayName) · \(calibration.model.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LayoutEstimate(model: calibration.model)
                    Text("Head movement is compensated. Recalibrate after moving the camera or switching displays.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Clear Calibration", role: .destructive, action: model.clearCalibration)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Physical layout the geometric model estimated during calibration.
private struct LayoutEstimate: View {
    let model: GazeCalibration

    var body: some View {
        let offsetMM = (model.cameraPosition - 0.5) * model.geometry.widthMM
        let weights = model.headRotationWeights
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            row("Camera", String(format: "%.0f mm above screen, %.0f mm %@ of center",
                                 model.cameraGapMM, abs(offsetMM), offsetMM < 0 ? "left" : "right"))
            row("Screen", String(format: "%.0f × %.0f mm", model.geometry.widthMM, model.geometry.heightMM))
            row("Your distance", String(format: "%.0f cm", model.calibrationDistanceMM / 10))
            row("Head weights", String(format: "yaw %+.2f, pitch %+.2f", weights.yaw, weights.pitch))
            row("Eye appearance model", model.appearanceRidge.map { String(format: "on (ridge %g)", $0) }
                ?? "off (didn't improve validation)")
        }
        .font(.callout)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}

/// Targets (rings) vs. mean predictions (dots) for each calibration point.
private struct ErrorPlot: View {
    let report: CalibrationReport
    let aspect: CGFloat

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(.primary.opacity(0.06)))
            for point in report.points {
                let t = CGPoint(x: point.target.x * size.width, y: point.target.y * size.height)
                let p = CGPoint(x: point.predicted.x * size.width, y: point.predicted.y * size.height)
                var line = Path()
                line.move(to: t)
                line.addLine(to: p)
                context.stroke(line, with: .color(.secondary), lineWidth: 1)
                context.stroke(Path(ellipseIn: CGRect(center: t, radius: 6)), with: .color(.secondary), lineWidth: 1)
                context.fill(Path(ellipseIn: CGRect(center: p, radius: 3)), with: .color(.accentColor))
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
    }
}

private struct GridIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.1))
            GeometryReader { geo in
                ForEach(0..<9, id: \.self) { i in
                    let x = [0.12, 0.5, 0.88][i % 3], y = [0.15, 0.5, 0.85][i / 3]
                    Circle()
                        .stroke(Color.accentColor.opacity(i == 4 ? 1 : 0.45), lineWidth: 1.5)
                        .frame(width: i == 4 ? 18 : 10, height: i == 4 ? 18 : 10)
                        .overlay(Circle().fill(.white).frame(width: 3, height: 3))
                        .position(x: x * geo.size.width, y: y * geo.size.height)
                }
            }
        }
    }
}
