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
        let gain = (Self.slowGain + (Self.fastGain - Self.slowGain) * Self.smoothstep(0.3, 2.5, speed)) * sensitivity
        // Hand up (y up) moves the cursor up (screen y down).
        cursor = CGPoint(x: min(max(cursor.x + dx * gain, bounds.minX), bounds.maxX - 1),
                         y: min(max(cursor.y - dy * gain, bounds.minY), bounds.maxY - 1))
        return cursor
    }

    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
