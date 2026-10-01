// Renders the app icon into an .iconset directory: swift scripts/make-icon.swift <out.iconset>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = s * 0.1
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.98, green: 0.47, blue: 0.36, alpha: 1),
                        NSColor(red: 0.45, green: 0.12, blue: 0.42, alpha: 1)])!.draw(in: squircle, angle: -90)

    // Sound wave: centered vertical rounded bars of varying heights.
    NSColor.white.setFill()
    let heights: [CGFloat] = [0.14, 0.30, 0.48, 0.34, 0.52, 0.28, 0.14]
    let bw = s * 0.055, gap = s * 0.035
    let total = CGFloat(heights.count) * bw + CGFloat(heights.count - 1) * gap
    for (i, h) in heights.enumerated() {
        let x = (s - total) / 2 + CGFloat(i) * (bw + gap)
        let bar = NSRect(x: x, y: (s - s * h) / 2, width: bw, height: s * h)
        NSBezierPath(roundedRect: bar, xRadius: bw / 2, yRadius: bw / 2).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
