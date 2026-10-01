import Foundation

/// Lets one shortcut work two ways: tap it to start hands-free recording and
/// tap again to stop, or hold it while talking and let go to finish.
public struct TalkTrigger: Sendable {
    public enum Action: Equatable, Sendable { case start, stop, none }

    /// Presses held at least this long count as push-to-talk.
    public var holdThreshold: TimeInterval
    private var pressStartedAt: TimeInterval?

    public init(holdThreshold: TimeInterval = 0.4) {
        self.holdThreshold = holdThreshold
    }

    public mutating func press(at time: TimeInterval, isRecording: Bool) -> Action {
        if isRecording {
            pressStartedAt = nil
            return .stop
        }
        pressStartedAt = time
        return .start
    }

    public mutating func release(at time: TimeInterval, isRecording: Bool) -> Action {
        defer { pressStartedAt = nil }
        guard isRecording, let start = pressStartedAt else { return .none }
        return time - start >= holdThreshold ? .stop : .none
    }
}
