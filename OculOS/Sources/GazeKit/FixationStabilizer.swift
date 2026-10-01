import CoreGraphics

/// Online fixation filter for a gaze cursor.
///
/// Webcam gaze noise is larger than the small eye movements within a fixation,
/// so a low-pass filter either jitters or lags. Instead this holds the output at
/// the running mean of the current fixation, and moves only once several
/// consecutive samples agree on a new location (a saccade). A single noisy
/// sample outside the radius is ignored.
public struct FixationStabilizer: Sendable {
    /// Samples within this distance of the fixation center belong to it.
    public var radius: Double
    /// Consecutive agreeing samples needed to accept a saccade.
    public var confirmSamples: Int
    /// Caps the running mean so a long fixation can still follow slow drift.
    public var maxWindow: Int

    private var center: CGPoint?
    private var count = 0
    private var candidates: [CGPoint] = []

    public init(radius: Double, confirmSamples: Int = 4, maxWindow: Int = 45) {
        self.radius = radius
        self.confirmSamples = confirmSamples
        self.maxWindow = maxWindow
    }

    public mutating func update(_ p: CGPoint) -> CGPoint {
        guard let c = center else {
            center = p
            count = 1
            return p
        }
        if p.distance(to: c) <= radius {
            candidates.removeAll()
            count = min(count + 1, maxWindow)
            let next = CGPoint(x: c.x + (p.x - c.x) / CGFloat(count), y: c.y + (p.y - c.y) / CGFloat(count))
            center = next
            return next
        }

        candidates.append(p)
        if candidates.count >= confirmSamples {
            let mean = candidates.centroid
            if candidates.allSatisfy({ $0.distance(to: mean) <= radius }) {
                center = mean
                count = candidates.count
                candidates.removeAll()
                return mean
            }
            candidates.removeFirst()
        }
        return c
    }

    public mutating func reset() {
        center = nil
        count = 0
        candidates.removeAll()
    }
}
