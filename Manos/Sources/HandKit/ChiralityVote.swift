import CoreGraphics
import Foundation

/// Vision labels left/right per frame and sometimes flips it. This locks each
/// hand's label to the majority of its last `window` labels, matching hands to
/// tracks by palm position, so one bad frame can't hand the pointer over.
public struct ChiralityVote: Sendable {
    public var window = 10
    private var tracks: [(anchor: CGPoint, seen: TimeInterval, votes: [HandPose.Chirality], label: HandPose.Chirality)] = []

    public init() {}

    public mutating func apply(_ hands: [HandPose]) -> [HandPose] {
        // No hand this frame: keep every track, so a brief dropout (motion blur) keeps its votes.
        guard let now = hands.first?.timestamp else { return [] }
        var old = tracks.filter { now - $0.seen < 0.5 }
        tracks = []
        let voted = hands.map { hand in
            // The nearest track within a few palm widths is the same hand.
            let near = old.indices.filter { old[$0].anchor.distance(to: hand.anchor) < 3 * hand.scale }
            let match = near.min { old[$0].anchor.distance(to: hand.anchor) < old[$1].anchor.distance(to: hand.anchor) }
            var track = match.map { old.remove(at: $0) } ?? (hand.anchor, hand.timestamp, [], .unknown)
            if hand.chirality != .unknown { track.votes = Array((track.votes + [hand.chirality]).suffix(window)) }
            let lefts = track.votes.filter { $0 == .left }.count * 2, n = track.votes.count
            if lefts != n { track.label = lefts > n ? .left : .right } // a tie keeps the old label
            track.anchor = hand.anchor
            track.seen = hand.timestamp
            tracks.append(track)
            var hand = hand
            hand.chirality = track.label
            return hand
        }
        tracks += old // unmatched tracks survive brief dropouts
        return voted
    }
}
