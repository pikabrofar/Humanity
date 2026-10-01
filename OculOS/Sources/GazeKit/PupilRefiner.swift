import CoreGraphics
import CoreVideo

/// Locates the pupil as the intensity-weighted centroid of the darkest pixels
/// inside the eye contour.
///
/// Vision's pupil landmark is a regression output and tends to jitter by a few
/// pixels; the dark blob of the iris/pupil is a much more stable signal on a
/// reasonably lit face.
final class PupilRefiner {
    /// Fraction of eye pixels (darkest first) that contribute to the centroid.
    var darkFraction = 0.22
    /// Reject refinements further than this (in eye widths) from Vision's estimate.
    var maxDeviation = 0.3

    private var values: [UInt8] = []
    private var coords: [(Int, Int)] = []

    /// - Parameters:
    ///   - pupil: Vision's pupil estimate, in pixel coordinates with origin bottom-left.
    ///   - eye: Eye contour, same coordinate space.
    /// - Returns: The refined pupil position, or nil if the frame is unsuitable.
    func refine(pupil: CGPoint, eye: [CGPoint], in pixelBuffer: CVPixelBuffer) -> CGPoint? {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let luma = base.assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

        // Flip to row-major (origin top-left) and shrink the contour vertically so
        // eyelashes along the lid margin don't pull the centroid upwards.
        let center = eye.centroid
        let polygon = eye.map { p in
            CGPoint(x: center.x + (p.x - center.x) * 0.9,
                    y: CGFloat(height) - (center.y + (p.y - center.y) * 0.75))
        }
        let xs = polygon.map(\.x), ys = polygon.map(\.y)
        let minX = max(0, Int(xs.min()!.rounded(.down))), maxX = min(width - 1, Int(xs.max()!.rounded(.up)))
        let minY = max(0, Int(ys.min()!.rounded(.down))), maxY = min(height - 1, Int(ys.max()!.rounded(.up)))
        let eyeWidth = maxX - minX
        guard eyeWidth >= 8, maxY - minY >= 3 else { return nil }

        values.removeAll(keepingCapacity: true)
        coords.removeAll(keepingCapacity: true)
        for y in minY...maxY {
            let row = luma + y * rowBytes
            for x in minX...maxX where polygon.contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) {
                values.append(row[x])
                coords.append((x, y))
            }
        }
        guard values.count >= 24 else { return nil }

        let threshold = Self.quantile(values, darkFraction)
        var sx = 0.0, sy = 0.0, sw = 0.0
        for (i, v) in values.enumerated() where v <= threshold {
            let w = Double(threshold - v) + 1
            sx += Double(coords[i].0) * w
            sy += Double(coords[i].1) * w
            sw += w
        }
        guard sw > 0 else { return nil }

        let refined = CGPoint(x: sx / sw + 0.5, y: Double(height) - (sy / sw + 0.5))
        let deviation = hypot(refined.x - pupil.x, refined.y - pupil.y) / CGFloat(eyeWidth)
        return deviation <= maxDeviation ? refined : nil
    }

    /// Histogram-based quantile; O(n) and allocation-free.
    static func quantile(_ values: [UInt8], _ q: Double) -> UInt8 {
        var histogram = [Int](repeating: 0, count: 256)
        for v in values { histogram[Int(v)] += 1 }
        let target = Int(Double(values.count) * q)
        var cumulative = 0
        for (level, n) in histogram.enumerated() {
            cumulative += n
            if cumulative > target { return UInt8(level) }
        }
        return 255
    }
}

extension Array where Element == CGPoint {
    /// Even-odd ray casting point-in-polygon test.
    func contains(_ p: CGPoint) -> Bool {
        var inside = false
        var j = count - 1
        for i in indices {
            let a = self[i], b = self[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
