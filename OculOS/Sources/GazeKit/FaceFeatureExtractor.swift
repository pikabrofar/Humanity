import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Result of analysing one camera frame.
public struct FrameAnalysis: Sendable {
    public var imageSize: CGSize
    public var features: GazeFeatures?
    public var landmarks: FaceLandmarksSnapshot?
}

/// Runs Vision face-landmark detection on camera frames and turns the landmarks
/// into head-pose-aware eye features.
///
/// Not thread-safe: call `analyze` from a single serial queue.
public final class FaceFeatureExtractor {
    /// Refine Vision's pupil landmark by locating the dark iris/pupil blob in the
    /// luma plane. Noticeably reduces jitter on well-lit faces.
    public var usesPupilRefinement = true

    /// A frame counts as a blink when openness falls below this fraction of the
    /// running baseline.
    public var blinkRatio = 0.65

    /// Optional appearance-based gaze CNN, run on the face crop each frame.
    public var network: GazeNetwork?

    private let request: VNDetectFaceLandmarksRequest
    /// Landmark results don't carry head pose; revision 3 face rectangles do.
    private let poseRequest: VNDetectFaceRectanglesRequest
    private let refiner = PupilRefiner()
    private var opennessBaseline: Double?

    public init() {
        request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        request.constellation = .constellation76Points
        poseRequest = VNDetectFaceRectanglesRequest()
        poseRequest.revision = VNDetectFaceRectanglesRequestRevision3
    }

    public func analyze(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> FrameAnalysis {
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        var result = FrameAnalysis(imageSize: size)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        guard (try? handler.perform([poseRequest])) != nil,
              let pose = poseRequest.results?.max(by: { $0.boundingBox.area < $1.boundingBox.area })
        else { return result }
        // Reuse the detected face so landmarks aren't searched for a second time.
        request.inputFaceObservations = [pose]
        guard (try? handler.perform([request])) != nil,
              let face = request.results?.first,
              let landmarks = face.landmarks,
              let leftRegion = landmarks.leftEye, let rightRegion = landmarks.rightEye
        else { return result }

        // Pixel coordinates, origin bottom-left (Vision convention).
        let leftEye = leftRegion.pointsInImage(imageSize: size)
        let rightEye = rightRegion.pointsInImage(imageSize: size)
        guard leftEye.count >= 4, rightEye.count >= 4 else { return result }

        var leftPupil = landmarks.leftPupil?.pointsInImage(imageSize: size).first ?? leftEye.centroid
        var rightPupil = landmarks.rightPupil?.pointsInImage(imageSize: size).first ?? rightEye.centroid
        if usesPupilRefinement {
            leftPupil = refiner.refine(pupil: leftPupil, eye: leftEye, in: pixelBuffer) ?? leftPupil
            rightPupil = refiner.refine(pupil: rightPupil, eye: rightEye, in: pixelBuffer) ?? rightPupil
        }

        // The inter-ocular line gives a more precise in-plane rotation than face.roll.
        let lc = leftEye.centroid, rc = rightEye.centroid
        let eyeLineAngle = atan2(Double(rc.y - lc.y), Double(rc.x - lc.x))

        let left = Self.eyeFeatures(contour: leftEye, pupil: leftPupil, angle: eyeLineAngle)
        let right = Self.eyeFeatures(contour: rightEye, pupil: rightPupil, angle: eyeLineAngle)

        let openness = (left.openness + right.openness) / 2
        let baseline = opennessBaseline ?? openness
        let isBlinking = openness < baseline * blinkRatio
        if !isBlinking {
            opennessBaseline = baseline * 0.97 + openness * 0.03
        }

        result.features = GazeFeatures(
            timestamp: timestamp,
            left: left,
            right: right,
            yaw: pose.yaw?.doubleValue ?? 0,
            pitch: pose.pitch?.doubleValue ?? 0,
            roll: pose.roll?.doubleValue ?? eyeLineAngle,
            faceCenter: CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY),
            faceSize: Double(face.boundingBox.width),
            isBlinking: isBlinking,
            appearance: EyePatch.features(contours: [leftEye, rightEye], angle: eyeLineAngle, in: pixelBuffer),
            networkGaze: isBlinking ? nil : network?.predict(face: face.boundingBox, imageSize: size, handler: handler)
        )

        let normalize = { (p: CGPoint) in CGPoint(x: p.x / size.width, y: p.y / size.height) }
        result.landmarks = FaceLandmarksSnapshot(
            faceBounds: face.boundingBox,
            leftEye: leftEye.map(normalize),
            rightEye: rightEye.map(normalize),
            leftPupil: normalize(leftPupil),
            rightPupil: normalize(rightPupil)
        )
        return result
    }

    /// Expresses the pupil relative to the eye corners, in a frame rotated so the
    /// eyes are level. Using the corners (not the contour centroid) as reference keeps
    /// the vertical feature stable when the upper lid moves.
    static func eyeFeatures(contour: [CGPoint], pupil: CGPoint, angle: Double) -> EyeFeatures {
        let c = contour.centroid
        let cosA = cos(-angle), sinA = sin(-angle)
        func rotate(_ p: CGPoint) -> CGPoint {
            let dx = Double(p.x - c.x), dy = Double(p.y - c.y)
            return CGPoint(x: dx * cosA - dy * sinA, y: dx * sinA + dy * cosA)
        }
        let pts = contour.map(rotate)
        guard let inner = pts.min(by: { $0.x < $1.x }), let outer = pts.max(by: { $0.x < $1.x }) else {
            return EyeFeatures(pupil: .zero, openness: 0)
        }
        let width = max(Double(outer.x - inner.x), 1e-6)
        let minY = pts.map(\.y).min() ?? 0, maxY = pts.map(\.y).max() ?? 0
        let cornerY = Double(inner.y + outer.y) / 2
        let p = rotate(pupil)
        return EyeFeatures(
            pupil: CGPoint(x: (Double(p.x) - Double(inner.x)) / width, y: (Double(p.y) - cornerY) / width),
            openness: Double(maxY - minY) / width
        )
    }
}

extension CGRect {
    var area: CGFloat { width * height }
}

extension Array where Element == CGPoint {
    public var centroid: CGPoint {
        guard !isEmpty else { return .zero }
        let sum = reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
    }
}
