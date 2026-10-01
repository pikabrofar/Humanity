import CoreGraphics
import Foundation

/// Keeps smooth-pursuit calibration samples only while the eyes were actually
/// following the target: within each short window, eye features must correlate
/// with target motion (Pfeuffer et al., UIST 2013).
public enum PursuitFilter {
    /// - Parameters:
    ///   - samples: Chronological samples whose targets move.
    ///   - window: Samples per window (15 ≈ 0.5 s at 30 fps).
    ///   - threshold: Minimum |Pearson r| on each axis the target moved along. Kept
    ///     low because webcam pupil features are noisy; saccade removal and robust
    ///     fitting handle the rest.
    public static func attended(_ samples: [CalibrationSample], window: Int = 15, threshold: Double = 0.3) -> [CalibrationSample] {
        stride(from: 0, to: samples.count, by: window).flatMap { start -> ArraySlice<CalibrationSample> in
            let chunk = samples[start..<min(start + window, samples.count)]
            guard chunk.count >= 5 else { return [] }
            let axes: [(eye: [Double], target: [Double])] = [
                (chunk.map { Double($0.features.eye.x) }, chunk.map { Double($0.target.x) }),
                (chunk.map { Double($0.features.eye.y) }, chunk.map { Double($0.target.y) }),
            ]
            // Ignore an axis the target barely moved along (e.g. at a turn).
            let moving = axes.filter { standardDeviation($0.target) > 0.01 }
            return moving.allSatisfy { abs(correlation($0.eye, $0.target)) >= threshold } ? chunk : []
        }
    }

    static func correlation(_ a: [Double], _ b: [Double]) -> Double {
        let ma = a.reduce(0, +) / Double(a.count), mb = b.reduce(0, +) / Double(b.count)
        var sab = 0.0, saa = 0.0, sbb = 0.0
        for (x, y) in zip(a, b) {
            sab += (x - ma) * (y - mb)
            saa += (x - ma) * (x - ma)
            sbb += (y - mb) * (y - mb)
        }
        return saa > 0 && sbb > 0 ? sab / (saa * sbb).squareRoot() : 0
    }

    static func standardDeviation(_ v: [Double]) -> Double {
        let m = v.reduce(0, +) / Double(v.count)
        return (v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(v.count)).squareRoot()
    }
}

extension PursuitFilter {
    /// Estimates the user's pursuit latency (plus display/camera lag) as the
    /// delay that best aligns eye movement with target movement.
    /// - Parameter path: Target position at time `t` seconds after `start`.
    public static func estimateLag(
        _ features: [GazeFeatures],
        start: TimeInterval,
        path: (Double) -> CGPoint,
        candidates: [Double] = stride(from: 0, through: 0.3, by: 1.0 / 60).map { $0 }
    ) -> Double {
        guard features.count >= 30 else { return 0.05 }
        let ex = features.map { Double($0.eye.x) }, ey = features.map { Double($0.eye.y) }
        func score(_ lag: Double) -> Double {
            let targets = features.map { path($0.timestamp - start - lag) }
            return abs(correlation(ex, targets.map { Double($0.x) })) + abs(correlation(ey, targets.map { Double($0.y) }))
        }
        return candidates.max { score($0) < score($1) } ?? 0.05
    }

    /// Drops catch-up saccades: frames where the eyes moved much faster than the
    /// smooth-pursuit baseline.
    public static func removeSaccades(_ samples: [CalibrationSample], factor: Double = 4) -> [CalibrationSample] {
        guard samples.count >= 3 else { return samples }
        let speeds = zip(samples, samples.dropFirst()).map { a, b in
            Double(hypot(b.features.eye.x - a.features.eye.x, b.features.eye.y - a.features.eye.y))
                / max(b.features.timestamp - a.features.timestamp, 1e-3)
        }
        let limit = factor * max(speeds.median, 1e-6)
        // Frame i+1 ends a fast step; drop it.
        return [samples[0]] + zip(samples.dropFirst(), speeds).filter { $0.1 <= limit }.map(\.0)
    }
}

/// Picks the part of a fixation-target recording where the user was actually
/// fixating: the longest stable fixation (I-DT on eye features). This discards
/// the saccade onto the dot, corrective "refocusing" saccades, and glances away.
public enum FixationSelector {
    public static func longestFixation(_ samples: [CalibrationSample], minDuration: TimeInterval = 0.3) -> [CalibrationSample] {
        guard samples.count >= 5 else { return [] }
        // Noise-adaptive threshold from the typical frame-to-frame step.
        let eyes = samples.map(\.features.eye)
        let steps = zip(eyes, eyes.dropFirst()).map { Double(abs($0.x - $1.x) + abs($0.y - $1.y)) }
        // ~8× the median step spans a noisy fixation without merging real saccades.
        let dispersion = min(max(steps.median * 8, 0.015), 0.12)
        let gaze = samples.map { GazeSample(t: $0.features.timestamp, x: Double($0.features.eye.x), y: Double($0.features.eye.y)) }
        guard let best = FixationDetector(maxDispersion: dispersion, minDuration: minDuration).detect(gaze)
            .max(by: { $0.duration < $1.duration })
        else { return [] }
        return samples.filter { $0.features.timestamp >= best.start && $0.features.timestamp <= best.end }
    }
}
