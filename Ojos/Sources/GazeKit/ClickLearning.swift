import CoreGraphics
import Foundation

/// Which frames before a click may teach the gaze model where the user looked.
public enum ClickLearning {
    /// The frames of the last 0.3 s, kept only when the gaze was steady (a
    /// fixation, not a saccade: two thirds within 1.5° of their median) and near
    /// the click (within 2.5× the calibration's accuracy, 3–8°). A click made
    /// while looking elsewhere, or mid-saccade, teaches nothing.
    /// - Parameters:
    ///   - recent: Frames, oldest first, each with the model's raw prediction in screen points.
    ///   - target: The click, in screen points.
    ///   - pointsPerDegree: At the current screen resolution.
    ///   - accuracyDegrees: The calibration's held-out accuracy.
    public static func select(_ recent: [(features: GazeFeatures, predicted: CGPoint)], target: CGPoint,
                              pointsPerDegree ppd: Double, accuracyDegrees: Double) -> [GazeFeatures] {
        guard let latest = recent.last?.features.timestamp else { return [] }
        let window = recent.filter { latest - $0.features.timestamp <= 0.3 }
        guard window.count >= 3 else { return [] }
        let median = CGPoint(x: window.map { Double($0.predicted.x) }.median, y: window.map { Double($0.predicted.y) }.median)
        let still = window.filter { $0.predicted.distance(to: median) <= 1.5 * ppd }
        let gate = min(max(2.5 * accuracyDegrees, 3), 8) * ppd
        guard 3 * still.count >= 2 * window.count, median.distance(to: target) <= gate else { return [] }
        return still.map(\.features)
    }
}
