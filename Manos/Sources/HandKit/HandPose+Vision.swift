import Vision

extension HandPose {
    private static let visionJoints: [(Joint, VNHumanHandPoseObservation.JointName)] = [
        (.wrist, .wrist),
        (.thumbCMC, .thumbCMC), (.thumbMP, .thumbMP), (.thumbIP, .thumbIP), (.thumbTip, .thumbTip),
        (.indexMCP, .indexMCP), (.indexPIP, .indexPIP), (.indexDIP, .indexDIP), (.indexTip, .indexTip),
        (.middleMCP, .middleMCP), (.middlePIP, .middlePIP), (.middleDIP, .middleDIP), (.middleTip, .middleTip),
        (.ringMCP, .ringMCP), (.ringPIP, .ringPIP), (.ringDIP, .ringDIP), (.ringTip, .ringTip),
        (.littleMCP, .littleMCP), (.littlePIP, .littlePIP), (.littleDIP, .littleDIP), (.littleTip, .littleTip),
    ]

    /// - Parameter imageAspect: Camera image width / height.
    /// - Parameter regionOfInterest: The request's crop; Vision reports points relative to it.
    public init?(observation: VNHumanHandPoseObservation, imageAspect: Double, timestamp: TimeInterval,
                 regionOfInterest roi: CGRect = HandPose.fullFrame, minConfidence: Float = 0.3) {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        var joints: [Joint: CGPoint] = [:]
        for (joint, name) in Self.visionJoints {
            guard let p = points[name], p.confidence >= minConfidence else { continue }
            let x = roi.minX + p.location.x * roi.width, y = roi.minY + p.location.y * roi.height
            // Mirror so x runs to the user's right; scale x so units are isotropic.
            joints[joint] = CGPoint(x: (1 - x) * imageAspect, y: y)
        }
        let chirality: Chirality = switch observation.chirality {
        case .left: .left
        case .right: .right
        default: .unknown
        }
        self.init(joints: joints, chirality: chirality, timestamp: timestamp)
    }

    public static let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Vision crop (normalized, unmirrored, origin bottom-left) around `hands`:
    /// their joints' bounding square grown `pad`×. Nil (use the full frame) when
    /// there are no hands or the crop would cover `maxArea` of the frame or more.
    public static func regionOfInterest(around hands: [HandPose], imageAspect: Double,
                                        pad: Double = 2, maxArea: Double = 0.15) -> CGRect? {
        let pts = hands.flatMap(\.joints.values)
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return nil }
        let a = CGFloat(imageAspect), side = max(maxX - minX, maxY - minY) * CGFloat(pad)
        // Undo the mirroring and aspect scaling of `init(observation:)`.
        let cx = 1 - (minX + maxX) / 2 / a, cy = (minY + maxY) / 2
        let roi = CGRect(x: cx - side / a / 2, y: cy - side / 2, width: side / a, height: side).intersection(fullFrame)
        return roi.isNull || Double(roi.width * roi.height) >= maxArea ? nil : roi
    }
}
