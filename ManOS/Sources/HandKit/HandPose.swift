import CoreGraphics
import Foundation

/// One tracked hand in a mirrored, aspect-corrected frame: x runs to the user's
/// right, y up, and one unit is the image height, so distances are isotropic.
public struct HandPose: Sendable, Equatable {
    public enum Joint: Int, CaseIterable, Sendable {
        case wrist
        case thumbCMC, thumbMP, thumbIP, thumbTip
        case indexMCP, indexPIP, indexDIP, indexTip
        case middleMCP, middlePIP, middleDIP, middleTip
        case ringMCP, ringPIP, ringDIP, ringTip
        case littleMCP, littlePIP, littleDIP, littleTip
    }

    public enum Chirality: Sendable, Equatable { case left, right, unknown }

    public var joints: [Joint: CGPoint]
    public var chirality: Chirality
    public var timestamp: TimeInterval

    /// Joints every gesture needs.
    static let required: [Joint] = [.wrist, .thumbTip, .indexTip, .middleTip, .indexMCP, .middleMCP, .littleMCP]

    /// Returns nil if a required joint is missing (low confidence).
    public init?(joints: [Joint: CGPoint], chirality: Chirality = .unknown, timestamp: TimeInterval) {
        guard Self.required.allSatisfy({ joints[$0] != nil }) else { return nil }
        self.joints = joints
        self.chirality = chirality
        self.timestamp = timestamp
    }

    public subscript(_ joint: Joint) -> CGPoint? { joints[joint] }

    private func p(_ joint: Joint) -> CGPoint { joints[joint]! } // required joints only

    /// Palm size: mean side of the wrist / index MCP / little MCP triangle. The
    /// palm is rigid, so this tracks distance to the camera, not finger pose.
    public var scale: Double {
        let w = p(.wrist), i = p(.indexMCP), l = p(.littleMCP)
        return max((w.distance(to: i) + w.distance(to: l) + i.distance(to: l)) / 3, 1e-4)
    }

    /// Cursor anchor: palm center. Fingertips move when you pinch; the palm
    /// barely does, so clicks don't drag the cursor off target.
    public var anchor: CGPoint {
        let pts = [p(.wrist), p(.indexMCP), p(.middleMCP), p(.littleMCP)]
        return CGPoint(x: pts.map(\.x).reduce(0, +) / 4, y: pts.map(\.y).reduce(0, +) / 4)
    }

    /// Thumb–index tip distance, in palm units.
    public var indexPinch: Double { p(.thumbTip).distance(to: p(.indexTip)) / scale }
    /// Thumb–middle tip distance, in palm units.
    public var middlePinch: Double { p(.thumbTip).distance(to: p(.middleTip)) / scale }

    /// A finger is extended when its tip is clearly farther from the wrist than its PIP joint.
    public func isExtended(tip: Joint, pip: Joint) -> Bool {
        guard let t = joints[tip], let m = joints[pip] else { return false }
        let w = p(.wrist)
        return t.distance(to: w) > m.distance(to: w) + 0.2 * scale
    }

    private var fingers: [(Joint, Joint)] {
        [(.indexTip, .indexPIP), (.middleTip, .middlePIP), (.ringTip, .ringPIP), (.littleTip, .littlePIP)]
    }

    /// At least three fingertips curled into the palm.
    public var isFist: Bool {
        let tips: [Joint] = [.indexTip, .middleTip, .ringTip, .littleTip]
        return tips.filter { joints[$0].map { $0.distance(to: anchor) < 0.9 * scale } ?? false }.count >= 3
    }

    /// All fingers extended *and spread*, thumb out. A relaxed pointing hand is
    /// also flat and extended, so spread is what makes this a deliberate signal.
    public var isOpenPalm: Bool {
        guard let indexTip = joints[.indexTip], let littleTip = joints[.littleTip] else { return false }
        let spread = indexTip.distance(to: littleTip) / max(p(.indexMCP).distance(to: p(.littleMCP)), 1e-4)
        return fingers.allSatisfy { isExtended(tip: $0.0, pip: $0.1) } && indexPinch > 1.0 && spread > 1.4
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> Double { Double(hypot(x - other.x, y - other.y)) }
}
