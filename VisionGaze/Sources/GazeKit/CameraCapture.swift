import AVFoundation
import CoreVideo

/// Thin wrapper around `AVCaptureSession` that delivers luma-friendly
/// (420 bi-planar) frames on a private serial queue.
public final class CameraCapture: NSObject, @unchecked Sendable {
    public let session = AVCaptureSession()

    public typealias FrameHandler = (CVPixelBuffer, TimeInterval) -> Void

    /// Several consumers can share one camera (e.g. gaze and hand tracking in Humanity).
    private var handlers: [UUID: FrameHandler] = [:]
    private let handlersLock = NSLock()

    private let queue = DispatchQueue(label: "GazeKit.CameraCapture", qos: .userInteractive)
    private let output = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput?

    public static var videoDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    public static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    /// Selects a camera (or the system default) and configures the session.
    /// - Parameters:
    ///   - preset: Preferred resolution; falls back to 720p, then `.high`.
    ///   - frameRate: Preferred frame rate (e.g. 60), if the camera has a format for it.
    public func configure(deviceID: String? = nil, preset: AVCaptureSession.Preset = .hd1920x1080,
                          frameRate: Double? = nil) throws {
        // Center Stage pans and zooms the frame, which trackers read as head or hand motion.
        if #available(macOS 12.3, *) {
            AVCaptureDevice.centerStageControlMode = .app
            AVCaptureDevice.isCenterStageEnabled = false
        }
        let device = deviceID.flatMap(AVCaptureDevice.init(uniqueID:))
            ?? AVCaptureDevice.default(for: .video)
        guard let device else { throw CameraError.noCamera }
        let newInput = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let input { session.removeInput(input) }
        guard session.canAddInput(newInput) else { throw CameraError.cannotAddInput }
        session.addInput(newInput)
        input = newInput

        // More pixels per eye = less pupil quantization noise.
        for candidate in [preset, .hd1280x720, .high] where session.canSetSessionPreset(candidate) {
            session.sessionPreset = candidate
            break
        }

        if let frameRate { prefer(frameRate: frameRate, on: device) }

        if !session.outputs.contains(output) {
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
            session.addOutput(output)
        }
    }

    public var currentDeviceID: String? { input?.device.uniqueID }

    /// Whether `configure` has been called successfully.
    public var isConfigured: Bool { input != nil }

    /// Registers a handler called on the capture queue for every frame.
    @discardableResult
    public func addFrameHandler(_ handler: @escaping FrameHandler) -> UUID {
        let id = UUID()
        handlersLock.withLock { handlers[id] = handler }
        return id
    }

    public func removeFrameHandler(_ id: UUID) {
        handlersLock.withLock { handlers[id] = nil }
    }

    /// Frames per second the camera is actually delivering at its max setting.
    public var activeFrameRate: Double {
        guard let device = input?.device else { return 0 }
        return 1 / max(device.activeVideoMinFrameDuration.seconds, 1e-3)
    }

    /// Picks the smallest ≥720p format that reaches `frameRate`. Most built-in
    /// Mac cameras top out at 30 fps; external and Continuity cameras often do 60.
    private func prefer(frameRate: Double, on device: AVCaptureDevice) {
        let candidates = device.formats.filter { format in
            let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return d.width >= 1280 && d.height >= 720
                && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= frameRate }
        }
        let area = { (f: AVCaptureDevice.Format) -> Int32 in
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            return d.width * d.height
        }
        guard let format = candidates.min(by: { area($0) < area($1) }),
              (try? device.lockForConfiguration()) != nil
        else { return }
        device.activeFormat = format
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        device.unlockForConfiguration()
    }

    public func start() {
        queue.async { [session] in if !session.isRunning { session.startRunning() } }
    }

    public func stop() {
        queue.async { [session] in if session.isRunning { session.stopRunning() } }
    }
}

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Host time (same clock as CACurrentMediaTime), so frames can be matched
        // to what was on screen, e.g. a moving calibration target.
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let host = session.synchronizationClock.map { CMSyncConvertTime(pts, from: $0, to: CMClockGetHostTimeClock()) } ?? pts
        for handler in handlersLock.withLock({ Array(handlers.values) }) {
            handler(pixelBuffer, host.seconds)
        }
    }
}

public enum CameraError: Error, LocalizedError {
    case noCamera, cannotAddInput, cannotAddOutput

    public var errorDescription: String? {
        switch self {
        case .noCamera: "No camera was found."
        case .cannotAddInput: "The camera could not be opened. Is another app using it?"
        case .cannotAddOutput: "The camera output could not be configured."
        }
    }
}
