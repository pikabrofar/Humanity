import CoreGraphics
import Foundation

/// Renders gaze density as a colorized, transparent heatmap image.
public enum HeatmapRenderer {
    /// - Parameters:
    ///   - points: Gaze points in normalized coordinates (0...1, origin top-left).
    ///   - aspectRatio: Width / height of the target surface.
    ///   - resolution: Width of the output image in pixels. Scale it up when drawing.
    ///   - radius: Gaussian kernel radius as a fraction of the image width.
    public static func render(
        points: [CGPoint],
        aspectRatio: Double,
        resolution: Int = 320,
        radius: Double = 0.035
    ) -> CGImage? {
        let width = max(resolution, 8)
        let height = max(Int((Double(width) / aspectRatio).rounded()), 8)
        let r = max(Int((radius * Double(width)).rounded()), 2)
        let sigma = Double(r) / 2.5

        var kernel = [Double](repeating: 0, count: (2 * r + 1) * (2 * r + 1))
        for dy in -r...r {
            for dx in -r...r {
                kernel[(dy + r) * (2 * r + 1) + (dx + r)] = exp(-Double(dx * dx + dy * dy) / (2 * sigma * sigma))
            }
        }

        var density = [Double](repeating: 0, count: width * height)
        for p in points where (0...1).contains(p.x) && (0...1).contains(p.y) {
            let cx = Int(p.x * CGFloat(width - 1)), cy = Int(p.y * CGFloat(height - 1))
            for dy in max(-r, -cy)...min(r, height - 1 - cy) {
                let rowOffset = (cy + dy) * width
                let kernelRow = (dy + r) * (2 * r + 1) + r
                for dx in max(-r, -cx)...min(r, width - 1 - cx) {
                    density[rowOffset + cx + dx] += kernel[kernelRow + dx]
                }
            }
        }

        guard let peak = density.max(), peak > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for i in density.indices {
            let v = density[i] / peak
            guard v > 0.02 else { continue }
            let (red, green, blue) = colormap(v)
            let alpha = min(1, v * 2.2) * 0.85
            // Premultiplied RGBA.
            pixels[i * 4 + 0] = UInt8(red * alpha * 255)
            pixels[i * 4 + 1] = UInt8(green * alpha * 255)
            pixels[i * 4 + 2] = UInt8(blue * alpha * 255)
            pixels[i * 4 + 3] = UInt8(alpha * 255)
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    /// Single warm hue: deep orange → the app's signal orange → amber → near
    /// white at the hottest spots. Ordered by lightness, so it reads correctly
    /// without color vision and on both light and dark backgrounds.
    static func colormap(_ v: Double) -> (Double, Double, Double) {
        let stops: [(Double, (Double, Double, Double))] = [
            (0.00, (0.80, 0.18, 0.10)),
            (0.40, (1.00, 0.42, 0.14)),
            (0.75, (1.00, 0.72, 0.28)),
            (1.00, (1.00, 0.95, 0.82)),
        ]
        let t = min(max(v, 0), 1)
        for i in 1..<stops.count where t <= stops[i].0 {
            let (t0, c0) = stops[i - 1], (t1, c1) = stops[i]
            let f = (t - t0) / (t1 - t0)
            return (c0.0 + (c1.0 - c0.0) * f, c0.1 + (c1.1 - c0.1) * f, c0.2 + (c1.2 - c0.2) * f)
        }
        return stops.last!.1
    }
}
