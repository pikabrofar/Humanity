import Accelerate
import CoreGraphics
import CoreVideo

/// Locates the iris/pupil center inside the eye contour.
///
/// Vision's pupil landmark is a regression output and tends to jitter by a few
/// pixels. At 720p one pixel is about 2–3° of eye rotation, so the center is
/// re-estimated from the image.
final class PupilRefiner {
    enum Method {
        /// Intensity-weighted centroid of the darkest pixels.
        case darkCentroid
        /// Timm & Barth (2011) means of gradients with a parabolic sub-pixel peak.
        /// Lower error and jitter on synthetic eyes (see `PupilRefinerTests`).
        case gradients
    }

    var method = Method.gradients
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
        // eyelashes along the lid margin don't pull the estimate upwards.
        let center = eye.centroid
        let polygon = eye.map { p in
            CGPoint(x: center.x + (p.x - center.x) * 0.9,
                    y: CGFloat(height) - (center.y + (p.y - center.y) * 0.75))
        }
        let xs = polygon.map(\.x), ys = polygon.map(\.y)
        let minX = max(1, Int(xs.min()!.rounded(.down))), maxX = min(width - 2, Int(xs.max()!.rounded(.up)))
        let minY = max(1, Int(ys.min()!.rounded(.down))), maxY = min(height - 2, Int(ys.max()!.rounded(.up)))
        let eyeWidth = maxX - minX
        guard eyeWidth >= 8, maxY - minY >= 3 else { return nil }

        let box = (minX, maxX, minY, maxY)
        let found = switch method {
        case .darkCentroid: darkCentroid(luma, rowBytes, polygon, box)
        case .gradients:
            gradientCenter(luma, rowBytes, width: width, height: height, polygon: polygon,
                           eye: eye.map { CGPoint(x: $0.x, y: CGFloat(height) - $0.y) }, box: box)
        }
        guard let found else { return nil }
        let refined = CGPoint(x: found.x, y: CGFloat(height) - found.y)
        let deviation = hypot(refined.x - pupil.x, refined.y - pupil.y) / CGFloat(eyeWidth)
        return deviation <= maxDeviation ? refined : nil
    }

    /// Row-major pixel coordinates (pixel centers at +0.5).
    private func darkCentroid(_ luma: UnsafePointer<UInt8>, _ rowBytes: Int, _ polygon: [CGPoint],
                              _ box: (Int, Int, Int, Int)) -> CGPoint? {
        let (minX, maxX, minY, maxY) = box
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
        return CGPoint(x: sx / sw + 0.5, y: sy / sw + 0.5)
    }

    /// Timm & Barth: the center is where most normalized displacement vectors
    /// agree with the image gradients (dark-to-bright edges pointing away from it).
    /// Gradients come from the full contour, candidates from the shrunken one, so
    /// lid edges contribute little (they point inwards). The paper's darkness
    /// weight is left out: inside the eye it only adds pixel noise to a flat peak
    /// (it raised jitter ~10× on the synthetic test).
    private func gradientCenter(_ luma: UnsafePointer<UInt8>, _ rowBytes: Int, width: Int, height: Int,
                                polygon: [CGPoint], eye: [CGPoint], box: (Int, Int, Int, Int)) -> CGPoint? {
        let ex = eye.map(\.x), ey = eye.map(\.y)
        let x0 = max(1, Int(ex.min()!.rounded(.down)) - 1), x1 = min(width - 2, Int(ex.max()!.rounded(.up)) + 1)
        let y0 = max(1, Int(ey.min()!.rounded(.down)) - 1), y1 = min(height - 2, Int(ey.max()!.rounded(.up)) + 1)
        let w = x1 - x0 + 1, h = y1 - y0 + 1
        guard w >= 8, h >= 4 else { return nil }

        // Luma patch → float; a 5×5 grayscale opening erases glints (small bright
        // spots) without moving the limbus; a 3×3 binomial blur (σ ≈ 0.85 px) for noise.
        var a = [Float](repeating: 0, count: w * h), b = a
        a.withUnsafeMutableBufferPointer { a in
            b.withUnsafeMutableBufferPointer { b in
                func buffer(_ p: UnsafeMutableBufferPointer<Float>) -> vImage_Buffer {
                    vImage_Buffer(data: p.baseAddress, height: vImagePixelCount(h), width: vImagePixelCount(w), rowBytes: w * 4)
                }
                var src = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: luma + y0 * rowBytes + x0),
                                        height: vImagePixelCount(h), width: vImagePixelCount(w), rowBytes: rowBytes)
                var fa = buffer(a), fb = buffer(b)
                let flags = vImage_Flags(kvImageEdgeExtend)
                vImageConvert_Planar8toPlanarF(&src, &fa, 255, 0, vImage_Flags(kvImageNoFlags))
                vImageMin_PlanarF(&fa, &fb, nil, 0, 0, 5, 5, flags)
                vImageMax_PlanarF(&fb, &fa, nil, 0, 0, 5, 5, flags)
                let kernel: [Float] = [1, 2, 1, 2, 4, 2, 1, 2, 1].map { $0 / 16 }
                vImageConvolve_PlanarF(&fa, &fb, nil, 0, 0, kernel, 3, 3, 0, flags)
            }
        }
        let img = b

        // Unit gradients inside the eye, above mean + 0.3σ of magnitude (as in the paper).
        var gx: [Float] = [], gy: [Float] = [], px: [Float] = [], py: [Float] = [], mag: [Float] = []
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) where eye.contains(CGPoint(x: CGFloat(x + x0) + 0.5, y: CGFloat(y + y0) + 0.5)) {
                let dx = (img[y * w + x + 1] - img[y * w + x - 1]) / 2
                let dy = (img[(y + 1) * w + x] - img[(y - 1) * w + x]) / 2
                gx.append(dx); gy.append(dy); mag.append((dx * dx + dy * dy).squareRoot())
                px.append(Float(x) + 0.5); py.append(Float(y) + 0.5)
            }
        }
        guard mag.count >= 24 else { return nil }
        var mean: Float = 0, std: Float = 0
        vDSP_normalize(mag, 1, nil, 1, &mean, &std, vDSP_Length(mag.count))
        let threshold = mean + 0.3 * std
        var keep: [Int] = []
        for i in mag.indices where mag[i] > threshold && mag[i] > 1 {
            gx[i] /= mag[i]; gy[i] /= mag[i]
            keep.append(i)
        }
        guard keep.count >= 8 else { return nil }

        // Objective on every pixel of the candidate box; the max must lie in the shrunken contour.
        let (minX, maxX, minY, maxY) = box
        let cw = maxX - minX + 1, ch = maxY - minY + 1
        var score = [Float](repeating: 0, count: cw * ch)
        var best = -1
        for j in 0..<ch {
            for i in 0..<cw {
                let cx = Float(minX + i - x0) + 0.5, cy = Float(minY + j - y0) + 0.5
                var sum: Float = 0
                for k in keep {
                    let dx = px[k] - cx, dy = py[k] - cy
                    let d2 = dx * dx + dy * dy
                    guard d2 > 0 else { continue }
                    let dot = (dx * gx[k] + dy * gy[k]) / d2.squareRoot()
                    if dot > 0 { sum += dot * dot }
                }
                score[j * cw + i] = sum
                if (best < 0 || sum > score[best]),
                   polygon.contains(CGPoint(x: CGFloat(minX + i) + 0.5, y: CGFloat(minY + j) + 0.5)) {
                    best = j * cw + i
                }
            }
        }
        guard best >= 0 else { return nil }

        // Parabolic sub-pixel peak along each axis.
        func offset(_ a: Float, _ b: Float, _ c: Float) -> Float {
            let d = a - 2 * b + c
            return d < 0 ? min(max((a - c) / (2 * d), -0.5), 0.5) : 0
        }
        let bi = best % cw, bj = best / cw
        let ox = bi > 0 && bi < cw - 1 ? offset(score[best - 1], score[best], score[best + 1]) : 0
        let oy = bj > 0 && bj < ch - 1 ? offset(score[best - cw], score[best], score[best + cw]) : 0
        return CGPoint(x: Double(minX + bi) + 0.5 + Double(ox), y: Double(minY + bj) + 0.5 + Double(oy))
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
