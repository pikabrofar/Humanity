import CoreGraphics
import Foundation

/// Dwell-to-click timer. Fires once when gaze stays within `radius` of where it
/// settled for `duration`. Leaving the radius cancels; firing again needs a new
/// fixation, so staring at a button doesn't click it repeatedly.
public struct Dwell: Sendable {
    public var duration: TimeInterval
    public var radius: Double
    /// Updates further apart than this mean there was no gaze in between (a blink,
    /// closed eyes), and the time beyond it doesn't count toward the dwell. For a
    /// caller that updates every camera frame; the default counts all time.
    public var maxGap = TimeInterval.infinity
    /// 0...1 toward the next click, for a progress ring.
    public private(set) var progress = 0.0

    private var anchor: CGPoint?
    private var start: TimeInterval = 0
    private var fired = false
    private var lastUpdate: TimeInterval?

    public init(duration: TimeInterval = 1, radius: Double = 100) {
        self.duration = duration
        self.radius = radius
    }

    /// - Returns: True when the dwell completes and a click should happen.
    public mutating func update(_ p: CGPoint?, at t: TimeInterval) -> Bool {
        defer { lastUpdate = p == nil ? nil : t }
        guard let p else {
            anchor = nil
            progress = 0
            return false
        }
        if anchor.map({ p.distance(to: $0) > radius }) ?? true {
            anchor = p
            start = t
            fired = false
        } else if let lastUpdate, t - lastUpdate > maxGap {
            start += t - lastUpdate - maxGap // no gaze meanwhile: that time wasn't spent looking
        }
        progress = fired ? 0 : min((t - start) / duration, 1)
        guard progress >= 1 else { return false }
        fired = true
        progress = 0
        return true
    }

    /// Abandons the current dwell (e.g. Esc). Like a completed one, it needs a new fixation to restart.
    public mutating func cancel() {
        fired = true
        progress = 0
    }
}
