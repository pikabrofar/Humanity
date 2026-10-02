import CoreGraphics
import Foundation

/// Picks the hand that drives the pointer when the camera sees more than one.
public enum HandSelection {
    /// - While a button is held, only the hand that pressed it counts: the hand
    ///   nearest `last`, if it is within two palm widths of it. Otherwise nil, so
    ///   losing that hand releases the button instead of passing the drag to the other hand.
    /// - Otherwise the dominant hand (the one nearest `last` if Vision labels
    ///   several that way), then the hand nearest `last`, then the largest.
    ///   Vision's result order never decides, so control can't flicker between hands.
    public static func pick(_ hands: [HandPose], dominant: HandPose.Chirality, last: HandPose?, holding: Bool) -> HandPose? {
        func nearest(_ pool: [HandPose], to last: HandPose) -> HandPose? {
            pool.min { $0.anchor.distance(to: last.anchor) < $1.anchor.distance(to: last.anchor) }
        }
        if holding, let last {
            return nearest(hands, to: last).flatMap { $0.anchor.distance(to: last.anchor) <= 2 * last.scale ? $0 : nil }
        }
        let preferred = hands.filter { $0.chirality == dominant }
        let pool = preferred.isEmpty ? hands : preferred
        if let last, let hand = nearest(pool, to: last) { return hand }
        return pool.max { $0.scale < $1.scale }
    }
}
