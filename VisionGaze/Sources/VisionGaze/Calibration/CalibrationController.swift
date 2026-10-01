import AppKit
import GazeKit
import Observation
import SwiftUI

/// Drives the calibration sequence, modelled on research and commercial trackers:
///
/// 1. 9-point fixation grid: stable anchors across the screen.
/// 2. Smooth pursuit: a dot on a Lissajous path gives hundreds of distinct
///    targets in seconds (Pfeuffer et al. 2013). Only windows where the eyes
///    demonstrably followed the dot are kept.
/// 3. Head motion: a fixed dot while the head moves, which identifies the head
///    parameters of the geometric model.
/// 4. Validation: 5 held-out points, scored Tobii-style (accuracy, precision),
///    and used to decide whether the eye-appearance correction helps.
@MainActor @Observable
final class CalibrationController {
    enum Phase: Equatable {
        case intro
        case countdown(Int)
        case running
        /// Dot moving along the pursuit path.
        case pursuit
        /// Center dot held while the user moves their head.
        case headMotion
        case validating
        case fitting
        case results
        case failed(String)
    }

    private(set) var phase: Phase = .intro
    /// Grid targets, in presentation order.
    let targets: [CGPoint]
    let validationTargets: [CGPoint]
    private(set) var currentIndex = 0
    private(set) var dotPosition = CGPoint(x: 0.5, y: 0.5)
    /// True while samples for the current target are being collected.
    private(set) var collecting = false
    private(set) var result: StoredCalibration?
    private(set) var headMotionRemaining = 0
    /// True while re-showing points the user missed.
    private(set) var retrying = false
    /// Host time (CACurrentMediaTime) at which the pursuit path started.
    private(set) var pursuitStart: CFTimeInterval = 0

    let screen: NSScreen
    @ObservationIgnored private let engine: GazeEngine
    @ObservationIgnored private let onClose: () -> Void
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Timing, in seconds.
    /// Covers saccade latency (~200 ms) plus travel; fixation selection handles the rest.
    static let settleTime = 0.5
    static let minCollectTime = 1.0
    static let maxCollectTime = 3.5
    /// Stop collecting once a fixation this long (frames) is found.
    static let minSamplesPerTarget = 24
    /// A point with a shorter longest fixation counts as missed.
    static let minFixationSamples = 12
    static let headMotionTime = 8
    static let pursuitDuration = 16.0
    /// Pursuit samples before this are dropped: the eyes need a moment to lock on.
    static let pursuitOnset = 1.0

    init(engine: GazeEngine, screen: NSScreen, onClose: @escaping () -> Void) {
        self.engine = engine
        self.screen = screen
        self.onClose = onClose
        targets = Self.makeTargets(margin: 0.08)
        validationTargets = [
            CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.25), CGPoint(x: 0.5, y: 0.4),
            CGPoint(x: 0.25, y: 0.75), CGPoint(x: 0.75, y: 0.75),
        ].shuffled()
    }

    /// Center first (comfortable start), remaining grid points shuffled so the
    /// user can't anticipate the next position.
    static func makeTargets(margin: Double) -> [CGPoint] {
        let stops = [margin, 0.5, 1 - margin]
        let grid = stops.flatMap { y in stops.map { x in CGPoint(x: x, y: y) } }
        let center = CGPoint(x: 0.5, y: 0.5)
        return [center] + grid.filter { $0 != center }.shuffled()
    }

    /// 2:3 Lissajous covering the screen; peak speed ≈ 12°/s on a laptop,
    /// inside the range where pursuit gain stays near 1.
    static func pursuitPoint(_ t: Double) -> CGPoint {
        let w = 2 * Double.pi * t / pursuitDuration
        return CGPoint(x: 0.5 + 0.42 * sin(2 * w), y: 0.5 + 0.4 * sin(3 * w + .pi / 2))
    }

    /// Dots shown in the progress bar for the current phase.
    var progressTotal: Int { phase == .validating ? validationTargets.count : targets.count }

    func begin() {
        guard phase == .intro || phase == .results || isFailed else { return }
        task?.cancel()
        task = Task { await run() }
    }

    func close() {
        task?.cancel()
        engine.calibrationSink = nil
        onClose()
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func run() async {
        result = nil
        currentIndex = 0
        dotPosition = targets[0]

        for n in stride(from: 3, through: 1, by: -1) {
            phase = .countdown(n)
            guard await pause(1) else { return }
        }

        phase = .running
        guard let grid = await collectFixations(targets) else { return }
        guard let pursuit = await collectPursuit() else { return }
        guard let head = await collectHeadMotion() else { return }
        phase = .validating
        guard let validation = await collectFixations(validationTargets) else { return }

        phase = .fitting
        let size = screen.physicalSizeMM
        let geometry = ScreenGeometry(widthMM: size.width, heightMM: size.height,
                                      imageAspect: engine.imageSize.width / engine.imageSize.height)
        let training = grid + pursuit + head
        do {
            let (model, check) = try await Task.detached(priority: .userInitiated) {
                // Score on held-out points first, then fold them in for the final model.
                let heldOut = try GazeCalibration.fit(samples: training, geometry: geometry, validation: validation)
                let check = heldOut.validate(validation)
                let final = try GazeCalibration.fit(samples: training + validation, geometry: geometry,
                                                    appearanceRidge: heldOut.appearanceRidge)
                return (final, check)
            }.value
            let stored = StoredCalibration(
                model: model,
                samples: training + validation,
                validation: check,
                displayID: screen.displayID,
                displayName: screen.localizedName,
                screenSize: screen.frame.size
            )
            result = stored
            engine.calibration = stored
            phase = .results
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Shows each target in turn and keeps only the frames of the user's
    /// longest stable fixation on it. Points where no usable fixation was found
    /// (looked away, face lost, eyes closed) are shown again once at the end.
    private func collectFixations(_ points: [CGPoint]) async -> [CalibrationSample]? {
        var samples: [CalibrationSample] = []
        var missed: [CGPoint] = []
        for pass in 0..<2 {
            let queue = pass == 0 ? points : missed
            missed = []
            retrying = pass == 1
            for (index, target) in queue.enumerated() {
                currentIndex = pass == 0 ? index : points.count - queue.count + index
                guard let fixation = await collectFixation(on: target) else { return nil }
                if fixation.count >= Self.minFixationSamples {
                    samples += fixation
                } else {
                    missed.append(target)
                }
            }
            if missed.isEmpty { break }
        }
        retrying = false
        return samples
    }

    /// Returns nil only when cancelled; an empty array means no usable fixation.
    private func collectFixation(on target: CGPoint) async -> [CalibrationSample]? {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { dotPosition = target }
        guard await pause(Self.settleTime) else { return nil }

        var collected: [CalibrationSample] = []
        engine.calibrationSink = { features in
            guard !features.isBlinking else { return }
            collected.append(CalibrationSample(features: features, target: target))
        }
        collecting = true
        let start = Date()
        var fixation: [CalibrationSample] = []
        while true {
            guard await pause(0.1) else { return nil }
            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= Self.minCollectTime {
                fixation = FixationSelector.longestFixation(collected)
                // Stop early once the user has held a steady fixation long enough.
                if fixation.count >= Self.minSamplesPerTarget { break }
            }
            if elapsed >= Self.maxCollectTime { break }
        }
        engine.calibrationSink = nil
        collecting = false
        return fixation
    }

    /// Frames are matched to where the dot was at capture time (camera
    /// timestamps are host time). The eye-to-target lag is estimated per user,
    /// catch-up saccades are removed, and windows where the eyes weren't
    /// following are dropped.
    private func collectPursuit() async -> [CalibrationSample]? {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { dotPosition = Self.pursuitPoint(0) }
        guard await pause(Self.settleTime) else { return nil }

        var frames: [GazeFeatures] = []
        pursuitStart = CACurrentMediaTime()
        phase = .pursuit
        let start = pursuitStart
        engine.calibrationSink = { features in
            let t = features.timestamp - start
            guard !features.isBlinking, t >= Self.pursuitOnset, t <= Self.pursuitDuration else { return }
            frames.append(features)
        }
        guard await pause(Self.pursuitDuration) else { return nil }
        engine.calibrationSink = nil
        dotPosition = Self.pursuitPoint(Self.pursuitDuration)

        let lag = PursuitFilter.estimateLag(frames, start: start, path: Self.pursuitPoint)
        let samples = frames.map { CalibrationSample(features: $0, target: Self.pursuitPoint($0.timestamp - start - lag)) }
        return PursuitFilter.attended(PursuitFilter.removeSaccades(samples))
    }

    /// Same target, varied head pose: identifies the head rotation weights and
    /// distance scale of the geometric model.
    private func collectHeadMotion() async -> [CalibrationSample]? {
        let center = CGPoint(x: 0.5, y: 0.5)
        phase = .headMotion
        headMotionRemaining = Self.headMotionTime
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { dotPosition = center }
        guard await pause(Self.settleTime) else { return nil }

        var samples: [CalibrationSample] = []
        engine.calibrationSink = { features in
            guard !features.isBlinking else { return }
            samples.append(CalibrationSample(features: features, target: center))
        }
        for remaining in stride(from: Self.headMotionTime, to: 0, by: -1) {
            headMotionRemaining = remaining
            guard await pause(1) else { return nil }
        }
        engine.calibrationSink = nil
        return samples
    }

    #if DEBUG
    /// Jumps straight to the results screen, for UI screenshots (see `Showcase`).
    func showcaseResults(_ stored: StoredCalibration) {
        task?.cancel()
        result = stored
        phase = .results
    }
    #endif

    /// Sleeps, returning false if the calibration was cancelled.
    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        if Task.isCancelled {
            engine.calibrationSink = nil
            collecting = false
            return false
        }
        return true
    }
}
