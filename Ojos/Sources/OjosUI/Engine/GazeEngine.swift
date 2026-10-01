import AppKit
import AVFoundation
import CoreVideo
import GazeKit
import Observation
import QuartzCore

enum CameraState: Equatable {
    case starting, running, denied
    case failed(String)
}

/// Owns the camera → Vision → calibration → smoothing pipeline and publishes
/// its state to the UI at frame rate.
@MainActor @Observable
final class GazeEngine {
    private(set) var cameraState: CameraState = .starting
    private(set) var imageSize = CGSize(width: 1280, height: 720)
    private(set) var landmarks: FaceLandmarksSnapshot?
    private(set) var features: GazeFeatures?
    private(set) var fps: Double = 0
    /// Smoothed gaze in normalized coordinates of `targetScreen`; nil when not tracking.
    private(set) var gaze: CGPoint? { didSet { onGaze?() } }
    /// Recent gaze points, newest last.
    private(set) var trail: [CGPoint] = []

    var calibration: StoredCalibration? {
        didSet {
            // Learned clicks (same explicit samples) arrive often: batch their saves.
            let learned = calibration != nil && oldValue?.samples.count == calibration?.samples.count
            scheduleSave(after: learned ? 5 : 0)
            if calibration == nil { gaze = nil }
        }
    }
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// Encodes and writes off the main actor; saves run in order and a newer one cancels a pending one.
    private func scheduleSave(after seconds: Double) {
        let previous = saveTask, calibration = calibration
        previous?.cancel()
        saveTask = Task.detached(priority: .utility) {
            await previous?.value
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            CalibrationStore.save(calibration)
        }
    }

    // MARK: Settings

    var cameraID: String? = Defaults.string(.cameraID) {
        didSet { Defaults.set(cameraID, .cameraID); Task { await start() } }
    }
    var pupilRefinement = Defaults.bool(.pupilRefinement, default: true) {
        didSet { Defaults.set(pupilRefinement, .pupilRefinement); processor.setRefinement(pupilRefinement) }
    }
    /// 0...1. Higher = larger fixation radius: steadier, but small eye movements are ignored.
    var stability = Defaults.double(.stability, default: 0.6) {
        didSet { Defaults.set(stability, .stability); applySmoothing() }
    }
    /// 0...1. Higher = fewer samples needed to confirm a saccade: faster, but more false jumps.
    /// 0.75 and up is one-sample look-ahead (research 05).
    var responsiveness = Defaults.double(.responsiveness, default: 0.75) {
        didSet { Defaults.set(responsiveness, .responsiveness); applySmoothing() }
    }

    // MARK: Consumers

    /// Receives every face frame (including blinks). Used by calibration.
    @ObservationIgnored var calibrationSink: ((GazeFeatures) -> Void)?
    /// Receives every smoothed gaze estimate. Used by recording.
    @ObservationIgnored var gazeSink: ((GazeSample) -> Void)?
    /// Called on every gaze update, including loss. Used by dwell clicking.
    @ObservationIgnored var onGaze: (() -> Void)?

    @ObservationIgnored private let camera: CameraCapture
    /// False when a host app (Sentidos) owns and configures a shared camera.
    @ObservationIgnored private let ownsCamera: Bool
    @ObservationIgnored private var frameHandler: UUID?
    @ObservationIgnored private let processor = FrameProcessor()
    @ObservationIgnored private var stabilizer = FixationStabilizer(radius: 80)
    /// Last non-blink frames, for learning from clicks.
    @ObservationIgnored private var recentFeatures: [GazeFeatures] = []
    @ObservationIgnored private var isRefitting = false
    @ObservationIgnored private var offscreenFrames = 0
    @ObservationIgnored private var lastFaceTime: CFTimeInterval = 0
    @ObservationIgnored private var lastFrameTime: CFTimeInterval = 0
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var fpsWindowStart: CFTimeInterval = 0
    @ObservationIgnored private var fpsFrames = 0

    var faceDetected: Bool { landmarks != nil }
    var isCalibrated: Bool { calibration != nil }
    /// Calibration needs live frames with a face in them.
    var canCalibrate: Bool { isActive && faceDetected }

    /// The display the current calibration maps onto.
    var targetScreen: NSScreen {
        calibration.flatMap { NSScreen.withDisplayID($0.displayID) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// The calibration's display is unplugged: gaze would land on the wrong screen.
    var calibratedDisplayMissing: Bool {
        calibration.map { NSScreen.withDisplayID($0.displayID) == nil } ?? false
    }

    var captureSession: AVCaptureSessionBox { AVCaptureSessionBox(session: camera.session) }

    /// Name of the loaded gaze CNN, or nil.
    private(set) var networkName: String?
    private(set) var networkError: String?

    /// Whether frames are processed. Off = no CPU spent on gaze.
    var isActive = true {
        didSet {
            processor.isActive = isActive
            if !isActive { gaze = nil; landmarks = nil; features = nil }
            lastFrameTime = CACurrentMediaTime() // the watchdog counts from now
            // Camera granted in System Settings after a denial: try again.
            if isActive, cameraState == .denied { Task { await start() } }
        }
    }

    init(camera: CameraCapture? = nil) {
        self.camera = camera ?? CameraCapture()
        ownsCamera = camera == nil
        calibration = CalibrationStore.load()
        processor.setRefinement(pupilRefinement)
        applySmoothing()
        loadNetwork()
    }

    private func loadNetwork() {
        guard FileManager.default.fileExists(atPath: ModelStore.compiledURL.path) else { return }
        do {
            processor.setNetwork(try GazeNetwork(compiledModelAt: ModelStore.compiledURL))
            networkName = ModelStore.displayName
            networkError = nil
        } catch {
            networkError = error.localizedDescription
        }
    }

    /// Compiles a Core ML model (.mlpackage / .mlmodel) and makes it the gaze CNN.
    func installNetwork(from url: URL) async {
        do {
            let compiled = url.pathExtension == "mlmodelc" ? url : try await GazeNetwork.compile(url)
            try ModelStore.install(compiled: compiled, name: url.deletingPathExtension().lastPathComponent)
            loadNetwork()
        } catch {
            networkError = error.localizedDescription
        }
    }

    func removeNetwork() {
        processor.setNetwork(nil)
        ModelStore.remove()
        networkName = nil
    }

    /// True when the calibration was made with a different CNN setup than now,
    /// so its CNN terms don't match the live features.
    var calibrationNeedsNetworkRefresh: Bool {
        guard let calibration else { return false }
        return calibration.usedNetwork != (networkName != nil)
    }

    func start() async {
        guard await CameraCapture.requestAccess() else {
            cameraState = .denied
            return
        }
        // Always configure, even a shared camera: gaze needs 1080p, and manoS only
        // configures a camera nobody has set up yet.
        do {
            try camera.configure(deviceID: cameraID)
        } catch {
            cameraState = .failed(error.localizedDescription)
            return
        }
        if frameHandler == nil {
            frameHandler = camera.addFrameHandler { [processor, weak self] pixelBuffer, timestamp in
                guard processor.isActive else { return } // paused module: skip the Vision work
                let analysis = processor.process(pixelBuffer, timestamp)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.handle(analysis) }
                }
            }
        }
        camera.start()
        cameraState = .running
        lastFrameTime = CACurrentMediaTime()
        // Frames stop when the camera is unplugged, taken by another app or fails.
        watchdog = watchdog ?? Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if isActive, cameraState == .running, CACurrentMediaTime() - lastFrameTime > 5 {
                    cameraState = .failed(camera.problem ?? "Camera stopped")
                }
            }
        }
    }

    private func handle(_ analysis: FrameAnalysis) {
        let now = CACurrentMediaTime()
        lastFrameTime = now
        if case .failed = cameraState { cameraState = .running } // frames are back
        countFrame(at: now)
        imageSize = analysis.imageSize
        landmarks = analysis.landmarks
        features = analysis.features

        guard let features = analysis.features else {
            if now - lastFaceTime > 0.4, gaze != nil {
                gaze = nil
                stabilizer.reset()
            }
            return
        }
        lastFaceTime = now
        calibrationSink?(features)

        // Hold the last estimate through blinks rather than jumping.
        guard !features.isBlinking else { return }
        recentFeatures.append(features)
        if recentFeatures.count > 15 { recentFeatures.removeFirst() }

        guard let calibration, let screen = NSScreen.withDisplayID(calibration.displayID) else {
            if gaze != nil { gaze = nil }
            return
        }
        let model = calibration.model, size = screen.frame.size
        var point = model.predict(features)
        // Looking away (at the keyboard, a phone, another screen): hide the
        // cursor after a few consistent frames instead of pinning it to an edge.
        let offscreen = point.x < -0.15 || point.x > 1.15 || point.y < -0.15 || point.y > 1.15
        offscreenFrames = offscreen ? offscreenFrames + 1 : 0
        if offscreenFrames >= 4 {
            gaze = nil
            stabilizer.reset()
            return
        }
        if offscreen { return }
        point.x = min(max(point.x, -0.02), 1.02) * size.width
        point.y = min(max(point.y, -0.02), 1.02) * size.height
        let stable = stabilizer.update(point, at: features.timestamp) // in points, so the radius is isotropic
        let smoothed = CGPoint(x: stable.x / size.width, y: stable.y / size.height)

        gaze = smoothed
        trail.append(smoothed)
        if trail.count > 24 { trail.removeFirst(trail.count - 24) }
        gazeSink?(GazeSample(t: features.timestamp, x: smoothed.x, y: smoothed.y))
    }

    private func countFrame(at now: CFTimeInterval) {
        fpsFrames += 1
        if now - fpsWindowStart >= 1 {
            fps = Double(fpsFrames) / (now - fpsWindowStart)
            fpsFrames = 0
            fpsWindowStart = now
        }
    }

    private func applySmoothing() {
        stabilizer.radius = fixationRadius
        stabilizer.confirmSamples = 4 - Int((2 * responsiveness).rounded()) // 4 … 2 frames
    }

    /// Fixation radius in screen points (30 … 150).
    var fixationRadius: Double { 30 + 120 * stability }

    /// Implicit recalibration: when the user clicks, they are almost always
    /// looking at the click point. The frames just before the click become
    /// calibration samples and the model is refit off the main thread. Clicks
    /// in varied head poses also sharpen the head-movement parameters.
    func learnFromClick(at target: CGPoint) {
        guard var stored = calibration, !calibratedDisplayMissing, let latest = recentFeatures.last else { return }
        let frames = recentFeatures.filter { latest.timestamp - $0.timestamp <= 0.25 }
        // A click far from the predicted gaze usually means the user wasn't looking.
        guard frames.count >= 3, let gaze, gaze.distance(to: target) < 0.25 else { return }

        stored.clickSamples.append(contentsOf: frames.map { CalibrationSample(features: $0, target: target) })
        stored.clickSamples = Array(stored.clickSamples.suffix(StoredCalibration.maxClickSamples))
        calibration = stored
        guard !isRefitting else { return } // samples join the next refit

        isRefitting = true
        let samples = stored.samples + stored.clickSamples, geometry = stored.model.geometry
        let ridge = stored.model.appearanceRidge
        Task {
            let model = await Task.detached(priority: .utility) {
                try? GazeCalibration.fit(samples: samples, geometry: geometry, appearanceRidge: ridge)
            }.value
            isRefitting = false
            if let model, calibration != nil { calibration?.model = model }
        }
    }
}

/// Runs Vision on the camera queue. The extractor is only touched from there.
private final class FrameProcessor: @unchecked Sendable {
    private let extractor = FaceFeatureExtractor()
    private let lock = NSLock()
    private var refinement = true
    private var network: GazeNetwork?
    private var active = true

    var isActive: Bool {
        get { lock.withLock { active } }
        set { lock.withLock { active = newValue } }
    }

    func setRefinement(_ enabled: Bool) {
        lock.withLock { refinement = enabled }
    }

    func setNetwork(_ network: GazeNetwork?) {
        lock.withLock { self.network = network }
    }

    func process(_ pixelBuffer: CVPixelBuffer, _ timestamp: TimeInterval) -> FrameAnalysis {
        lock.withLock {
            extractor.usesPupilRefinement = refinement
            extractor.network = network
        }
        return extractor.analyze(pixelBuffer: pixelBuffer, timestamp: timestamp)
    }
}

/// Lets views reach the capture session without making it observable state.
struct AVCaptureSessionBox {
    let session: AVCaptureSession
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    static func withDisplayID(_ id: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == id }
    }

    /// Physical size in millimetres.
    var physicalSizeMM: CGSize {
        let mm = CGDisplayScreenSize(displayID)
        // ponytail: 0.21 mm/pt fallback is MacBook-class; wrong for big monitors that don't report their size.
        return mm.width > 0 ? mm : CGSize(width: frame.width * 0.21, height: frame.height * 0.21)
    }
}
