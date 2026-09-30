import CoreGraphics
import CoreVideo

/// WebGazer-style appearance features: each eye resampled to a small grayscale
/// patch aligned to its corners, then histogram-equalized so lighting changes
/// matter less (Papoutsaki et al., IJCAI 2016).
enum EyePatch {
    static let columns = 10
    static let rows = 6

    /// - Parameters:
    ///   - contours: Eye contours in pixel coordinates, origin bottom-left.
    ///   - angle: In-plane rotation of the eye line, radians.
    /// - Returns: `columns × rows` values per eye, in [0, 1], or empty on failure.
    static func features(contours: [[CGPoint]], angle: Double, in pixelBuffer: CVPixelBuffer) -> [Float] {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        else { return [] }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return [] }
        let luma = base.assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

        func sample(_ p: CGPoint) -> Float {
            // Bilinear; flip y to row-major.
            let x = min(max(Double(p.x) - 0.5, 0), Double(width - 2))
            let y = min(max(Double(height) - Double(p.y) - 0.5, 0), Double(height - 2))
            let x0 = Int(x), y0 = Int(y), fx = x - Double(x0), fy = y - Double(y0)
            let r0 = luma + y0 * rowBytes, r1 = r0 + rowBytes
            let top = Double(r0[x0]) * (1 - fx) + Double(r0[x0 + 1]) * fx
            let bottom = Double(r1[x0]) * (1 - fx) + Double(r1[x0 + 1]) * fx
            return Float(top * (1 - fy) + bottom * fy)
        }

        let axis = CGPoint(x: cos(angle), y: sin(angle))
        let up = CGPoint(x: -axis.y, y: axis.x)
        var result: [Float] = []
        result.reserveCapacity(contours.count * columns * rows)
        for contour in contours {
            // Corners = extremes along the eye line.
            let projections = contour.map { Double($0.x * axis.x + $0.y * axis.y) }
            guard let lo = projections.indices.min(by: { projections[$0] < projections[$1] }),
                  let hi = projections.indices.max(by: { projections[$0] < projections[$1] })
            else { return [] }
            let a = contour[lo], b = contour[hi]
            let eyeWidth = Double(hypot(b.x - a.x, b.y - a.y))
            guard eyeWidth >= 6 else { return [] }
            let center = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let patchHeight = eyeWidth * 0.6

            var patch: [Float] = []
            for j in 0..<rows {
                let v = (0.5 - (Double(j) + 0.5) / Double(rows)) * patchHeight // top row first
                for i in 0..<columns {
                    let u = ((Double(i) + 0.5) / Double(columns) - 0.5) * eyeWidth
                    patch.append(sample(CGPoint(x: Double(center.x) + u * Double(axis.x) + v * Double(up.x),
                                                y: Double(center.y) + u * Double(axis.y) + v * Double(up.y))))
                }
            }
            result += equalized(patch)
        }
        return result
    }

    /// Histogram equalization of a small patch = each pixel's rank, scaled to [0, 1].
    static func equalized(_ values: [Float]) -> [Float] {
        let order = values.indices.sorted { values[$0] < values[$1] }
        var out = [Float](repeating: 0, count: values.count)
        let scale = Float(max(values.count - 1, 1))
        for (rank, index) in order.enumerated() { out[index] = Float(rank) / scale }
        return out
    }
}
