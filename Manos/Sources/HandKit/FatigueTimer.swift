import Foundation

/// Continuous hand use. Resting `rest` seconds (hand down or out of view)
/// restarts the count (research/10: 20 min backstop, ~15 s rest recovers).
public struct FatigueTimer: Sendable {
    public static let breakAfter: TimeInterval = 20 * 60
    public static let rest: TimeInterval = 15

    private var start: TimeInterval?
    private var lastActive = -TimeInterval.infinity

    public init() {}

    /// Seconds of continuous use so far.
    public mutating func update(active: Bool, at t: TimeInterval) -> TimeInterval {
        if t - lastActive > Self.rest { start = nil }
        guard let since = start ?? (active ? t : nil) else { return 0 }
        start = since
        if active { lastActive = t }
        return lastActive - since
    }
}
