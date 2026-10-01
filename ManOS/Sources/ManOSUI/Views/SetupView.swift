import AVFoundation
import HandKit
import Observation
import SwiftUI

/// First-run quick setup: camera → Accessibility → hand calibration → practice.
/// Also reachable from the sidebar at any time.
struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var calibration: HandCalibration?

    var body: some View {
        let cameraOK = model.engine.cameraState == .running
        let calibrated = calibration?.step == .done
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Setup").font(.largeTitle.weight(.semibold))
                    Text("Three steps, about a minute. Everything runs on this Mac; video never leaves it.")
                        .foregroundStyle(.secondary)
                }

                StepCard(number: 1, title: "Camera", done: cameraOK,
                         detail: "ManOS watches your hand through the camera.") {
                    if model.engine.cameraState == .denied {
                        Button("Open Camera Settings") { SystemSettings.open(.camera) }
                    }
                }

                StepCard(number: 2, title: "Accessibility", done: model.canControl,
                         detail: "Lets ManOS move the pointer and click. macOS asks once; turn ManOS on in the list that opens.") {
                    if !model.canControl {
                        HStack {
                            Button("Grant Access") { Permissions.requestControl() }
                                .buttonStyle(.borderedProminent)
                            Button("Open Accessibility Settings") { SystemSettings.open(.accessibility) }
                        }
                        Text("Not in the list? Click + under the list and choose ManOS, or drag it in from Finder. Already on but not working? Remove ManOS with – and add it again (macOS forgets it after updates).")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Show ManOS in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                        }
                        .font(.caption)
                    }
                }

                StepCard(number: 3, title: "Fit to your hand", done: calibrated,
                         detail: "Measures your relaxed hand and your pinch so clicks trigger reliably. Rest your elbow on the desk and keep your hand low, just above the keyboard: less tiring, like a trackpad.") {
                    if let calibration {
                        CalibrationPanel(calibration: calibration)
                    } else {
                        Button("Start") { calibration = HandCalibration(engine: model.engine) }
                            .buttonStyle(.borderedProminent)
                            .disabled(!cameraOK)
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        model.completeSetup()
                        model.setControl(true)
                    } label: {
                        Label("Finish and Try It", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!cameraOK || !model.canControl)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Quick Setup")
        .onDisappear { calibration?.stop() }
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

private struct CalibrationPanel: View {
    let calibration: HandCalibration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch calibration.step {
            case .relaxed:
                Label("Elbow on the desk, hand low, relaxed and open, facing the camera.", systemImage: "hand.raised")
                ProgressView(value: calibration.progress)
            case .pinch:
                Label("Pinch thumb and index finger together, then release. \(calibration.pinchesDone)/3",
                      systemImage: "hand.pinch")
                ProgressView(value: Double(calibration.pinchesDone), total: 3)
            case .done:
                Label(String(format: "Done. Click threshold %.2f, release %.2f.",
                             calibration.result?.pinchEnter ?? 0, calibration.result?.pinchExit ?? 0),
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if calibration.step != .done, !calibration.handVisible {
                Text("Raise your hand so the camera can see it.").font(.caption).foregroundStyle(.orange)
            }
        }
        .animation(.default, value: calibration.step)
    }
}

/// Measures the relaxed thumb–index distance, then the minimum reached during
/// three pinches, and derives per-user thresholds from them.
@MainActor @Observable
final class HandCalibration {
    enum Step { case relaxed, pinch, done }

    private(set) var step = Step.relaxed
    private(set) var progress = 0.0
    private(set) var pinchesDone = 0
    private(set) var handVisible = false
    private(set) var result: HandProfile?

    @ObservationIgnored private let engine: HandEngine
    @ObservationIgnored private var relaxed: [Double] = []
    @ObservationIgnored private var minima: [Double] = []
    @ObservationIgnored private var currentMin = Double.infinity
    @ObservationIgnored private var closed = false
    @ObservationIgnored private var visibilityTask: Task<Void, Never>?

    init(engine: HandEngine) {
        self.engine = engine
        engine.poseSink = { [weak self] pose in self?.observe(pose) }
        visibilityTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self else { return }
                self.handVisible = engine.activeHand != nil
            }
        }
    }

    func stop() {
        engine.poseSink = nil
        visibilityTask?.cancel()
    }

    private func observe(_ pose: HandPose) {
        let d = pose.indexPinch
        switch step {
        case .relaxed:
            relaxed.append(d)
            progress = Double(relaxed.count) / 45 // ~1.5 s
            if relaxed.count >= 45 { step = .pinch }
        case .pinch:
            let open = relaxed.median
            // A pinch is a dip below half the relaxed distance, then back above 70%.
            if d < open * 0.5 {
                closed = true
                currentMin = min(currentMin, d)
            } else if closed, d > open * 0.7 {
                closed = false
                minima.append(currentMin)
                currentMin = .infinity
                pinchesDone = minima.count
                if minima.count >= 3 { finish(open: open) }
            }
        case .done:
            break
        }
    }

    private func finish(open: Double) {
        let profile = HandProfile.calibrated(open: open, pinched: minima.median, base: engine.profile)
        engine.profile = profile
        result = profile
        step = .done
        stop()
    }
}

extension Array where Element == Double {
    var median: Double {
        guard !isEmpty else { return 0 }
        let s = sorted()
        return s.count.isMultiple(of: 2) ? (s[s.count / 2 - 1] + s[s.count / 2]) / 2 : s[s.count / 2]
    }
}
