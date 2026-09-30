import AVFoundation
import CoreVideo

/// Thin wrapper around `AVCaptureSession` that delivers luma-friendly
/// (420 bi-planar) frames on a private serial queue.
public final class CameraCapture: NSObject, @unchecked Sendable {
    public let session = AVCaptureSession()

    /// Called on the capture queue for every frame. Set before `start()`.
    public var onFrame: ((CVPixelBuffer, TimeInterval) -> Void)?

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
    public func configure(deviceID: String? = nil) throws {
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
        for preset in [AVCaptureSession.Preset.hd1920x1080, .hd1280x720, .high] where session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
            break
        }

        if !session.outputs.contains(output) {
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
            session.addOutput(output)
        }
    }

    public var currentDeviceID: String? { input?.device.uniqueID }

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
        onFrame?(pixelBuffer, host.seconds)
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
