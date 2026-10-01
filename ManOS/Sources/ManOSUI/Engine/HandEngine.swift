import AppKit
import AVFoundation
import GazeKit
import HandKit
import Observation
import QuartzCore
import Vision

enum CameraState: Equatable {
    case starting, running, denied
    case failed(String)
}

/// Camera → Vision hand pose → gesture recognizer → mouse events.
@MainActor @Observable
final class HandEngine {
    private(set) var cameraState: CameraState = .starting
    private(set) var imageSize = CGSize(width: 1280, height: 720)
    /// Every detected hand, for the skeleton overlay.
    private(set) var hands: [HandPose] = []
    /// The hand driving the pointer.
    private(set) var activeHand: HandPose?
    private(set) var fps: Double = 0
    private(set) var gesture: GestureRecognizer.State = .idle
    private(set) var isPaused = false
    private(set) var pinchProgress = 0.0
    private(set) var cursor = CGPoint.zero
    /// True briefly after the physical mouse moved.
    private(set) var yieldingToMouse = false

    /// Whether hand input actually controls the Mac.
    var isEnabled = false {
        didSet {
            if !isEnabled { release() }
            syncCursorToMouse()
        }
    }

    var profile: HandProfile {
        didSet {
            recognizer.profile = profile
            ProfileStore.save(profile)
        }
    }
    var dominantHand: HandPose.Chirality = Defaults.bool(.leftHanded, default: false) ? .left : .right {
        didSet { Defaults.set(dominantHand == .left, .leftHanded) }
    }

    /// Receives the active hand every frame (used by hand calibration).
    @ObservationIgnored var poseSink: ((HandPose) -> Void)?

    @ObservationIgnored private let camera: CameraCapture
    /// False when a host app (Humanity) owns and configures a shared camera.
    @ObservationIgnored private let ownsCamera: Bool
    @ObservationIgnored private var frameHandler: UUID?
    @ObservationIgnored private let processor = HandProcessor()
    @ObservationIgnored private let injector = EventInjector()
    @ObservationIgnored private var recognizer: GestureRecognizer
    @ObservationIgnored private var mouseYieldUntil: CFTimeInterval = 0
    @ObservationIgnored private var fpsWindowStart: CFTimeInterval = 0
    @ObservationIgnored private var fpsFrames = 0

    /// Whether frames are processed. Off = no CPU spent on hands, control released.
    var isActive = true {
        didSet {
            processor.isActive = isActive
            if !isActive {
                isEnabled = false
                hands = []
                activeHand = nil
            }
        }
    }

    init(camera: CameraCapture? = nil) {
        self.camera = camera ?? CameraCapture()
        ownsCamera = camera == nil
        let profile = ProfileStore.load()
        self.profile = profile
        recognizer = GestureRecognizer(profile: profile, mapper: PointerMapper(bounds: Self.displayBounds, cursor: .zero))
        recognizer.doubleClickInterval = NSEvent.doubleClickInterval
        syncCursorToMouse()
    }

    /// Union of all displays in global coordinates (origin top-left of the main display).
    static var displayBounds: CGRect {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.map(CGDisplayBounds).reduce(CGRect.null) { $0.union($1) }
    }

    var captureSession: AVCaptureSession { camera.session }

    func start() async {
        guard await CameraCapture.requestAccess() else {
            cameraState = .denied
            return
        }
        if ownsCamera || !camera.isConfigured {
            do {
                // Hand pose doesn't need 1080p; 720p and 60 fps (when available) keep latency down.
                try camera.configure(preset: .hd1280x720, frameRate: 60)
            } catch {
                cameraState = .failed(error.localizedDescription)
                return
            }
        }
        if frameHandler == nil {
            frameHandler = camera.addFrameHandler { [processor, weak self] pixelBuffer, timestamp in
                guard processor.isActive else { return } // paused module: skip the Vision work
                let result = processor.process(pixelBuffer, timestamp)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.handle(result) }
                }
            }
        }
        camera.start()
        cameraState = .running
    }

    func release() {
        for event in recognizer.releaseAll() where isEnabled { injector.post(event) }
        injector.releaseAll()
        gesture = recognizer.state
    }

    private func handle(_ result: HandProcessor.Result) {
        let now = CACurrentMediaTime()
        countFrame(at: now)
        imageSize = result.imageSize
        hands = result.hands
        recognizer.mapper.bounds = Self.displayBounds

        let hand = pickHand(result.hands)
        activeHand = hand
        if let hand { poseSink?(hand) }

        // The physical mouse wins: if the cursor moved without us, pause hand
        // input for a moment and continue from wherever the mouse left it.
        if let real = CGEvent(source: nil)?.location, let posted = injector.lastPosted,
           isEnabled, real.distance(to: posted) > 3, !recognizer.isButtonDown {
            mouseYieldUntil = now + 1.5
            recognizer.setCursor(real)
            injector.releaseAll()
        }
        yieldingToMouse = now < mouseYieldUntil
        if yieldingToMouse {
            // Disengage fully; the hand re-engages (250 ms dwell) once the mouse is idle.
            _ = recognizer.releaseAll()
            syncCursorToMouse()
            gesture = recognizer.state
            return
        }
        if !isEnabled { syncCursorToMouse() }

        let events = recognizer.update(hand, at: result.timestamp)
        gesture = recognizer.state
        isPaused = recognizer.isPaused
        pinchProgress = recognizer.pinchProgress
        cursor = recognizer.mapper.cursor

        guard isEnabled, !yieldingToMouse, Permissions.canControl else { return }
        for event in events { injector.post(event) }
    }

    /// Dominant hand if Vision can tell; otherwise the one closest to the last
    /// active hand (identity tracking), otherwise the largest.
    private func pickHand(_ hands: [HandPose]) -> HandPose? {
        if let match = hands.first(where: { $0.chirality == dominantHand }) { return match }
        if let last = activeHand {
            return hands.min { $0.anchor.distance(to: last.anchor) < $1.anchor.distance(to: last.anchor) }
        }
        return hands.max { $0.scale < $1.scale }
    }

    private func syncCursorToMouse() {
        if let real = CGEvent(source: nil)?.location {
            recognizer.setCursor(real)
            cursor = real
        }
    }

    private func countFrame(at now: CFTimeInterval) {
        fpsFrames += 1
        if now - fpsWindowStart >= 1 {
            fps = Double(fpsFrames) / (now - fpsWindowStart)
            fpsFrames = 0
            fpsWindowStart = now
        }
    }
}

/// Runs Vision on the camera queue.
private final class HandProcessor: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true

    var isActive: Bool {
        get { lock.withLock { active } }
        set { lock.withLock { active = newValue } }
    }

    struct Result {
        var imageSize: CGSize
        var hands: [HandPose]
        var timestamp: TimeInterval
    }

    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()

    func process(_ pixelBuffer: CVPixelBuffer, _ timestamp: TimeInterval) -> Result {
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
        let aspect = size.width / max(size.height, 1)
        let hands = (request.results ?? []).compactMap {
            HandPose(observation: $0, imageAspect: aspect, timestamp: timestamp)
        }
        return Result(imageSize: size, hands: hands, timestamp: timestamp)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> Double { Double(hypot(x - other.x, y - other.y)) }
}
