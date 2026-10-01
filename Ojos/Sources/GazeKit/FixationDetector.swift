import CoreGraphics
import Foundation

public struct Fixation: Sendable, Equatable {
    public var start: TimeInterval
    public var end: TimeInterval
    /// Centroid in the same coordinate space as the input samples.
    public var center: CGPoint
    public var duration: TimeInterval { end - start }
}

/// Dispersion-threshold fixation identification (I-DT, Salvucci & Goldberg 2000).
public struct FixationDetector: Sendable {
    /// Maximum (x-range + y-range) of a fixation, in the samples' units.
    public var maxDispersion: Double
    /// Minimum fixation duration in seconds.
    public var minDuration: TimeInterval

    public init(maxDispersion: Double, minDuration: TimeInterval = 0.1) {
        self.maxDispersion = maxDispersion
        self.minDuration = minDuration
    }

    /// `samples` must be sorted by time.
    public func detect(_ samples: [GazeSample]) -> [Fixation] {
        var fixations: [Fixation] = []
        var start = 0
        while start < samples.count {
            // Grow an initial window that spans minDuration.
            var end = start
            while end < samples.count, samples[end].t - samples[start].t < minDuration { end += 1 }
            guard end < samples.count else { break }

            if dispersion(samples[start...end]) <= maxDispersion {
                while end + 1 < samples.count, dispersion(samples[start...(end + 1)]) <= maxDispersion { end += 1 }
                let window = samples[start...end]
                let n = Double(window.count)
                fixations.append(Fixation(
                    start: samples[start].t,
                    end: samples[end].t,
                    center: CGPoint(x: window.reduce(0) { $0 + $1.x } / n, y: window.reduce(0) { $0 + $1.y } / n)
                ))
                start = end + 1
            } else {
                start += 1
            }
        }
        return fixations
    }

    private func dispersion(_ window: ArraySlice<GazeSample>) -> Double {
        var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
        for s in window {
            minX = min(minX, s.x); maxX = max(maxX, s.x)
            minY = min(minY, s.y); maxY = max(maxY, s.y)
        }
        return (maxX - minX) + (maxY - minY)
    }
}
