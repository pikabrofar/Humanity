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
    public init?(observation: VNHumanHandPoseObservation, imageAspect: Double, timestamp: TimeInterval,
                 minConfidence: Float = 0.3) {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        var joints: [Joint: CGPoint] = [:]
        for (joint, name) in Self.visionJoints {
            guard let p = points[name], p.confidence >= minConfidence else { continue }
            // Mirror so x runs to the user's right; scale x so units are isotropic.
            joints[joint] = CGPoint(x: (1 - p.location.x) * imageAspect, y: p.location.y)
        }
        let chirality: Chirality = switch observation.chirality {
        case .left: .left
        case .right: .right
        default: .unknown
        }
        self.init(joints: joints, chirality: chirality, timestamp: timestamp)
    }
}
