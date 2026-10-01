import CoreGraphics
import CoreVideo
import Testing
@testable import GazeKit

/// Synthetic eyes: a dark iris (with darker pupil) on sclera, clipped by
/// elliptical lids on skin, anti-aliased at sub-pixel centers, plus sensor noise.
/// Sizes match a face at ~60 cm on a 1080p webcam (eye ≈ 64 px, iris ≈ 22 px).
@Suite struct PupilRefinerTests {
    static let width = 160, height = 100
    static let eyeCenter = CGPoint(x: 80, y: 50), eyeA = 32.0, eyeB = 12.0

    /// Eye contour in Vision's convention (pixels, origin bottom-left).
    static let contour: [CGPoint] = (0..<16).map { i in
        let t = Double(i) / 16 * 2 * .pi
        return CGPoint(x: eyeCenter.x + eyeA * cos(t), y: CGFloat(height) - (eyeCenter.y + eyeB * sin(t)))
    }

    /// `iris` is the true center in row-major pixel coordinates.
    /// `hard`: dark brown iris with almost no pupil contrast, shading across the eye, and a glint.
    static func image(iris: CGPoint, noise: Double, hard: Bool, rng: inout SeededRandom) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, &buffer)
        let pb = buffer!
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        let luma = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!.assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
        for y in 0..<height {
            for x in 0..<width {
                var sum = 0.0
                for sy in 0..<4 { for sx in 0..<4 {
                    let u = Double(x) + (Double(sx) + 0.5) / 4, v = Double(y) + (Double(sy) + 0.5) / 4
                    let ex = (u - eyeCenter.x) / eyeA, ey = (v - eyeCenter.y) / eyeB
                    let r = hypot(u - iris.x, v - iris.y)
                    var level: Double = ex * ex + ey * ey > 1 ? 150 : r < 4.5 ? (hard ? 52 : 30) : r < 11 ? (hard ? 60 : 75) : (hard ? 165 : 195)
                    if hard {
                        level += (u - eyeCenter.x) * 0.8
                        if hypot(u - iris.x - 3, v - iris.y + 3) < 1.5 { level = 240 }
                    }
                    sum += level
                } }
                luma[y * rowBytes + x] = UInt8(min(max(sum / 16 + rng.gaussian() * noise, 0), 255))
            }
        }
        return pb
    }

    /// Mean error and jitter (RMS deviation from each center's mean estimate), in px.
    static func measure(_ method: PupilRefiner.Method, hard: Bool) -> (error: Double, jitter: Double) {
        var rng = SeededRandom(seed: 7)
        let refiner = PupilRefiner()
        refiner.method = method
        var errors: [Double] = [], deviations: [Double] = []
        for _ in 0..<12 {
            // Gaze anywhere across the eye, at a sub-pixel position.
            let iris = CGPoint(x: eyeCenter.x + (rng.next() - 0.5) * 30, y: eyeCenter.y + (rng.next() - 0.5) * 4)
            var estimates: [CGPoint] = []
            for _ in 0..<8 {
                let pb = image(iris: iris, noise: 8, hard: hard, rng: &rng)
                // Vision's estimate: truth plus a couple of pixels of error.
                let vision = CGPoint(x: iris.x + rng.gaussian() * 2, y: CGFloat(height) - iris.y + rng.gaussian() * 2)
                guard let p = refiner.refine(pupil: vision, eye: contour, in: pb) else { continue }
                let rowMajor = CGPoint(x: p.x, y: CGFloat(height) - p.y)
                estimates.append(rowMajor)
                errors.append(rowMajor.distance(to: iris))
            }
            let mean = estimates.centroid
            deviations += estimates.map { pow($0.distance(to: mean), 2) }
        }
        #expect(errors.count >= 90, "refiner rejected too many frames")
        return (errors.reduce(0, +) / Double(errors.count), (deviations.reduce(0, +) / Double(deviations.count)).squareRoot())
    }

    @Test(arguments: [false, true]) func gradientsBeatDarkCentroid(hard: Bool) {
        let old = Self.measure(.darkCentroid, hard: hard), new = Self.measure(.gradients, hard: hard)
        print(String(format: "PupilRefiner hard=\(hard) px: darkCentroid error %.3f jitter %.3f, gradients error %.3f jitter %.3f",
                     old.error, old.jitter, new.error, new.jitter))
        #expect(new.error < old.error)
        #expect(new.jitter < old.jitter)
        #expect(new.error < 0.5)
    }
}
