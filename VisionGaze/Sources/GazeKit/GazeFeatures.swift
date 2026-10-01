import CoreGraphics
import Foundation

/// Per-eye appearance features, expressed in an eye-local frame that is
/// rotation-compensated (roll) and scale-normalized by the eye's width.
public struct EyeFeatures: Codable, Sendable, Equatable {
    /// Pupil position. `x` runs from 0 (one eye corner) to 1 (the other corner);
    /// `y` is the vertical offset from the line joining the corners, divided by eye width.
    public var pupil: CGPoint
    /// Eye aspect ratio: contour height / contour width. Drops sharply during blinks.
    public var openness: Double

    public init(pupil: CGPoint, openness: Double) {
        self.pupil = pupil
        self.openness = openness
    }
}

/// Everything the calibration model needs from one camera frame.
public struct GazeFeatures: Codable, Sendable, Equatable {
    public var timestamp: TimeInterval
    public var left: EyeFeatures
    public var right: EyeFeatures
    /// Head pose in radians, as reported by Vision.
    public var yaw: Double
    public var pitch: Double
    public var roll: Double
    /// Face bounding-box center in normalized image coordinates (origin bottom-left).
    public var faceCenter: CGPoint
    /// Face bounding-box width, normalized to image width. A proxy for distance to camera.
    public var faceSize: Double
    /// True when the eyes are closed or mid-blink; such frames should not be used.
    public var isBlinking: Bool
    /// Equalized eye-patch pixels (both eyes), for the appearance model. May be empty.
    public var appearance: [Float]
    /// Gaze angles from the CNN, in radians, when a model is loaded.
    public var networkGaze: CGPoint?

    public init(
        timestamp: TimeInterval, left: EyeFeatures, right: EyeFeatures,
        yaw: Double, pitch: Double, roll: Double,
        faceCenter: CGPoint, faceSize: Double, isBlinking: Bool, appearance: [Float] = [],
        networkGaze: CGPoint? = nil
    ) {
        self.timestamp = timestamp
        self.left = left
        self.right = right
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.faceCenter = faceCenter
        self.faceSize = faceSize
        self.isBlinking = isBlinking
        self.appearance = appearance
        self.networkGaze = networkGaze
    }

    /// Binocular average of the pupil position; averaging both eyes halves the noise.
    public var eye: CGPoint {
        CGPoint(x: (left.pupil.x + right.pupil.x) / 2, y: (left.pupil.y + right.pupil.y) / 2)
    }

    public var openness: Double { (left.openness + right.openness) / 2 }

    /// Raw feature vector consumed by `GazeCalibration`.
    var rawVector: [Double] {
        // Openness tracks vertical gaze: the upper lid follows the eye down.
        [Double(eye.x), Double(eye.y), openness, yaw, pitch, Double(faceCenter.x), Double(faceCenter.y), faceSize]
    }
}

/// Landmark geometry for drawing debug overlays. All points are normalized image
/// coordinates in Vision's convention (0...1, origin at the bottom-left).
public struct FaceLandmarksSnapshot: Sendable, Equatable {
    public var faceBounds: CGRect
    public var leftEye: [CGPoint]
    public var rightEye: [CGPoint]
    public var leftPupil: CGPoint
    public var rightPupil: CGPoint

    public init(faceBounds: CGRect, leftEye: [CGPoint], rightEye: [CGPoint], leftPupil: CGPoint, rightPupil: CGPoint) {
        self.faceBounds = faceBounds
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftPupil = leftPupil
        self.rightPupil = rightPupil
    }
}

/// A single gaze estimate in normalized screen coordinates (0...1, origin top-left).
public struct GazeSample: Codable, Sendable, Equatable {
    public var t: TimeInterval
    public var x: Double
    public var y: Double

    public init(t: TimeInterval, x: Double, y: Double) {
        self.t = t
        self.x = x
        self.y = y
    }

    public var point: CGPoint { CGPoint(x: x, y: y) }
}
