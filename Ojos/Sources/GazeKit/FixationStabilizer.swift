import CoreGraphics
import Foundation

/// Online fixation filter for a gaze cursor.
///
/// Webcam gaze noise is larger than the small eye movements within a fixation,
/// so a low-pass filter either jitters or lags. Instead this holds the output at
/// a weighted mean of the current fixation, and moves only once consecutive
/// samples agree on a new location (a saccade). A single noisy sample outside
/// the radius is dropped.
///
/// With `confirmSamples` = 2 this is Kumar et al.'s one-sample look-ahead
/// (EyePoint, 2008): an outside sample is held for one frame and accepted only if
/// the next one lands near it. The fixation mean covers the last `window`
/// seconds with triangular weights, newest highest (Špakov 2012), so it follows
/// slow drift and restarts at two samples after a saccade.
public struct FixationStabilizer: Sendable {
    /// Samples within this distance of the fixation center belong to it.
    public var radius: Double
    /// Consecutive agreeing outside samples needed to accept a saccade.
    public var confirmSamples: Int
    /// Seconds of fixation history averaged.
    public var window: TimeInterval

    private var center: CGPoint?
    private var fixation: [(p: CGPoint, t: TimeInterval)] = []
    private var candidates: [(p: CGPoint, t: TimeInterval)] = []

    public init(radius: Double, confirmSamples: Int = 2, window: TimeInterval = 0.45) {
        self.radius = radius
        self.confirmSamples = confirmSamples
        self.window = window
    }

    /// - Parameter t: Sample time in seconds.
    public mutating func update(_ p: CGPoint, at t: TimeInterval) -> CGPoint {
        guard let c = center else {
            center = p
            fixation = [(p, t)]
            return p
        }
        if p.distance(to: c) <= radius {
            candidates.removeAll()
            fixation.append((p, t))
        } else {
            candidates.append((p, t))
            guard candidates.count >= confirmSamples else { return c }
            let mean = candidates.map(\.p).centroid
            guard candidates.allSatisfy({ $0.p.distance(to: mean) <= radius }) else {
                candidates.removeFirst()
                return c
            }
            fixation = candidates
            candidates.removeAll()
        }
        fixation.removeAll { t - $0.t > window }

        var x = 0.0, y = 0.0, total = 0.0
        for (i, s) in fixation.enumerated() {
            let w = Double(i + 1)
            x += s.p.x * w
            y += s.p.y * w
            total += w
        }
        let next = CGPoint(x: x / total, y: y / total)
        center = next
        return next
    }

    public mutating func reset() {
        center = nil
        fixation.removeAll()
        candidates.removeAll()
    }
}
