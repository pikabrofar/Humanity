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

    /// Flick the hand up/down to jump to the next/previous item (short videos,
    /// pages, slides).
    public var flickEnabled = true
    /// Vertical travel within 0.25 s that counts as a flick, in palm units.
    public var flickDistance = 1.3
    public var flickAction = FlickAction.scroll
    /// Pixels scrolled per flick in `.scroll` mode.
    public var flickScrollAmount = 700.0

    public enum FlickAction: String, Codable, Sendable, CaseIterable {
        /// A smooth scroll burst; works in any scrollable app or page.
        case scroll
        /// ↓/↑ arrow keys: the most reliable "next video" in Shorts, TikTok, Reels, slides.
        case arrowKeys
    }

    public init() {}

    // Decode field by field so profiles saved before a field existed keep
    // their calibrated thresholds instead of resetting.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = HandProfile()
        pinchEnter = try c.decodeIfPresent(Double.self, forKey: .pinchEnter) ?? d.pinchEnter
        pinchExit = try c.decodeIfPresent(Double.self, forKey: .pinchExit) ?? d.pinchExit
        sensitivity = try c.decodeIfPresent(Double.self, forKey: .sensitivity) ?? d.sensitivity
        scrollSpeed = try c.decodeIfPresent(Double.self, forKey: .scrollSpeed) ?? d.scrollSpeed
        invertScroll = try c.decodeIfPresent(Bool.self, forKey: .invertScroll) ?? d.invertScroll
        flickEnabled = try c.decodeIfPresent(Bool.self, forKey: .flickEnabled) ?? d.flickEnabled
        flickDistance = try c.decodeIfPresent(Double.self, forKey: .flickDistance) ?? d.flickDistance
        flickAction = try c.decodeIfPresent(FlickAction.self, forKey: .flickAction) ?? d.flickAction
        flickScrollAmount = try c.decodeIfPresent(Double.self, forKey: .flickScrollAmount) ?? d.flickScrollAmount
    }

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
