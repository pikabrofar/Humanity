import Foundation

/// Per-user tuning. Distances are in palm units (see `HandPose.scale`).
public struct HandProfile: Codable, Sendable, Equatable {
    /// A pinch starts below this thumb–fingertip distance…
    public var pinchEnter = 0.30
    /// …and ends above this one. The gap (hysteresis) stops flicker at the boundary.
    public var pinchExit = 0.45
    public var sensitivity = 1.0
    /// Pixels of scroll per palm-width of hand travel.
    public var scrollSpeed = 600.0
    /// Default is "grab the page": hand up moves the content up.
    public var invertScroll = false

    public init() {}

    /// Thresholds from measured distances: the median while the hand is relaxed
    /// and the minimum reached while pinching.
    public static func calibrated(open: Double, pinched: Double, base: HandProfile = HandProfile()) -> HandProfile {
        var profile = base
        let range = max(open - pinched, 0.2)
        profile.pinchEnter = min(max(pinched + 0.35 * range, 0.15), 0.6)
        profile.pinchExit = min(max(pinched + 0.6 * range, profile.pinchEnter + 0.08), 0.8)
        return profile
    }
}
