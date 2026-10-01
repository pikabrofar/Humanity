import CoreGraphics
import Foundation

/// The 1€ filter (Casiez et al., CHI 2012): smooths strongly when the hand is
/// slow (precise pointing) and follows quickly when it moves fast.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double

    private var previous: Double?
    private var previousDerivative = 0.0
    private var previousTime: TimeInterval?

    public init(minCutoff: Double = 1.0, beta: Double = 0.8, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    public mutating func filter(_ value: Double, at time: TimeInterval) -> Double {
        guard let prev = previous, let prevTime = previousTime, time > prevTime else {
            previous = value
            previousTime = time
            return value
        }
        let dt = time - prevTime
        let derivative = Self.lerp(previousDerivative, (value - prev) / dt, Self.alpha(derivativeCutoff, dt))
        let result = Self.lerp(prev, value, Self.alpha(minCutoff + beta * abs(derivative), dt))
        previous = result
        previousDerivative = derivative
        previousTime = time
        return result
    }

    public mutating func reset() {
        previous = nil
        previousTime = nil
        previousDerivative = 0
    }

    private static func alpha(_ cutoff: Double, _ dt: Double) -> Double { 1 / (1 + 1 / (2 * .pi * cutoff * dt)) }
    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

public struct OneEuroFilter2D: Sendable {
    private var x: OneEuroFilter
    private var y: OneEuroFilter

    public init(minCutoff: Double = 1.0, beta: Double = 0.8) {
        x = OneEuroFilter(minCutoff: minCutoff, beta: beta)
        y = OneEuroFilter(minCutoff: minCutoff, beta: beta)
    }

    public mutating func filter(_ p: CGPoint, at time: TimeInterval) -> CGPoint {
        CGPoint(x: x.filter(Double(p.x), at: time), y: y.filter(Double(p.y), at: time))
    }

    public mutating func reset() {
        x.reset()
        y.reset()
    }
}
