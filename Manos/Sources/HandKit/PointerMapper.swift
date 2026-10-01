import CoreGraphics
import Foundation

/// Relative ("trackpad") mapping from hand motion to cursor motion, with
/// pointer acceleration: slow movements are precise, fast ones cross the screen.
///
/// Input is the palm anchor in palm units, so the same hand motion moves the
/// cursor the same amount whether the hand is near or far from the camera.
public struct PointerMapper: Sendable {
    /// Allowed cursor region in global display coordinates (origin top-left).
    public var bounds: CGRect
    public var cursor: CGPoint
    /// Multiplies both ends of the acceleration curve.
    public var sensitivity: Double
    /// Individual display frames (global coordinates). When set, the cursor is
    /// kept on an actual display: the bounding box of an L-shaped or offset
    /// arrangement has dead zones macOS would silently clamp away.
    public var displays: [CGRect] = []
    /// Extra gain multiplier, e.g. lowered while a pinch is closing.
    public var damping = 1.0

    /// Points of cursor travel per palm-width of hand travel, at low and high speed.
    static let slowGain = 350.0
    static let fastGain = 1800.0

    private var last: CGPoint?
    private var lastTime: TimeInterval?

    public init(bounds: CGRect, cursor: CGPoint, sensitivity: Double = 1) {
        self.bounds = bounds
        self.cursor = cursor
        self.sensitivity = sensitivity
    }

    /// Sets the reference point without moving the cursor (after a clutch, engage, etc.).
    public mutating func track(_ anchor: CGPoint, at time: TimeInterval) {
        last = anchor
        lastTime = time
    }

    public mutating func update(_ anchor: CGPoint, at time: TimeInterval) -> CGPoint {
        defer { track(anchor, at: time) }
        guard let last, let lastTime else { return cursor }
        let dx = Double(anchor.x - last.x), dy = Double(anchor.y - last.y)
        let speed = hypot(dx, dy) / max(time - lastTime, 1e-3) // palm widths / s
        let gain = (Self.slowGain + (Self.fastGain - Self.slowGain) * Self.smoothstep(0.3, 2.5, speed)) * sensitivity * damping
        // Hand up (y up) moves the cursor up (screen y down).
        cursor = clamp(CGPoint(x: cursor.x + dx * gain, y: cursor.y - dy * gain))
        return cursor
    }

    func clamp(_ p: CGPoint) -> CGPoint {
        func inside(_ r: CGRect) -> CGPoint {
            CGPoint(x: min(max(p.x, r.minX), r.maxX - 1), y: min(max(p.y, r.minY), r.maxY - 1))
        }
        guard !displays.isEmpty else { return inside(bounds) }
        if displays.contains(where: { $0.contains(p) }) { return p }
        // Off-screen or in a gap: snap to the nearest point on any display.
        return displays.map(inside).min { $0.distance(to: p) < $1.distance(to: p) }!
    }

    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
