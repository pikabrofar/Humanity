import Foundation

/// Blink detection from eye openness, with hysteresis.
///
/// A blink starts when openness falls below `enter` × the baseline. It lasts until
/// the eye has reopened to `reopen` × its openness before the blink, so the
/// half-open frames on either side, which the gaze model reads as a downward
/// glance, are held too. Narrower eyes for longer than `adaptAfter` (a squint, a
/// new head pose) become the new baseline. Eyes below `closed` × the baseline
/// count as a blink however long they stay shut, and never become the baseline.
public struct BlinkDetector: Sendable {
    public var enter = 0.65
    public var reopen = 0.85
    public var closed = 0.4
    /// A blink lasts at least this long after its last low frame, so one noisy open frame doesn't end it.
    public var refractory: TimeInterval = 0.08
    public var adaptAfter: TimeInterval = 0.5

    private var baseline: Double?
    private var lowSince: TimeInterval?
    private var lastLow = -Double.infinity
    private var inBlink = false
    /// The last few open readings before a blink: what "reopened" is measured against.
    private var recentOpen: [Double] = []

    public init() {}

    /// - Returns: Whether this frame is part of a blink.
    public mutating func update(openness: Double, at t: TimeInterval) -> Bool {
        let base = baseline ?? openness
        if openness < base * enter {
            lowSince = lowSince ?? t
            lastLow = t
        } else {
            lowSince = nil
        }
        if let lowSince {
            inBlink = t - lowSince <= adaptAfter || openness < base * closed
        } else {
            inBlink = inBlink && (openness < reopen * (recentOpen.max() ?? base) || t - lastLow < refractory)
        }
        if !inBlink {
            baseline = base * 0.97 + openness * 0.03
            if lowSince == nil { recentOpen = Array((recentOpen + [openness]).suffix(3)) }
        }
        return inBlink
    }

    /// Forgets the baseline, e.g. when the face is lost.
    public mutating func reset() {
        baseline = nil
        lowSince = nil
        lastLow = -.infinity
        inBlink = false
        recentOpen = []
    }
}
