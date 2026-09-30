import Foundation

/// Flags blinks as eye openness dropping well below a running baseline.
///
/// The baseline is seeded from the median of the first frames (not frame 1,
/// which may be wide-eyed), and a "blink" longer than `maxBlinkDuration` is
/// treated as a new resting openness (a squint, looking down, glare) and
/// re-seeds the baseline. Otherwise a bad baseline would flag every later frame
/// as a blink and tracking would stop for good.
public struct BlinkDetector: Sendable {
    /// A frame counts as a blink when openness falls below this fraction of the baseline.
    public var blinkRatio = 0.65
    /// Spontaneous blinks last about 100–400 ms; longer closures re-seed the baseline.
    public var maxBlinkDuration: TimeInterval = 0.4
    /// Frames whose median seeds the baseline.
    public var seedFrames = 15

    public private(set) var baseline: Double?
    private var seed: [Double] = []
    private var blinkStart: TimeInterval?

    public init() {}

    /// Returns whether this frame is a blink.
    public mutating func update(openness: Double, timestamp: TimeInterval) -> Bool {
        guard let current = baseline else {
            seed.append(openness)
            let median = seed.sorted()[seed.count / 2]
            if seed.count >= seedFrames {
                baseline = median
                seed.removeAll()
            }
            return openness < median * blinkRatio
        }

        guard openness < current * blinkRatio else {
            blinkStart = nil
            baseline = current * 0.97 + openness * 0.03
            return false
        }
        let start = blinkStart ?? timestamp
        blinkStart = start
        if timestamp - start > maxBlinkDuration {
            baseline = nil
            blinkStart = nil
            seed = [openness]
            return false
        }
        // Drift slowly even while closed, so a slightly high baseline recovers.
        baseline = current * 0.995 + openness * 0.005
        return true
    }
}
