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
    NSGradient(colors: [NSColor(red: 0.42, green: 0.25, blue: 0.95, alpha: 1),
                        NSColor(red: 0.12, green: 0.08, blue: 0.35, alpha: 1)])!.draw(in: squircle, angle: -90)

    // Cursor arrow with a soft, fingertip-round point, and a small spark where it "touches".
    let arrow = NSBezierPath()
    for (i, p) in [(0.36, 0.66), (0.36, 0.27), (0.46, 0.36), (0.54, 0.21),
                   (0.62, 0.25), (0.545, 0.40), (0.67, 0.42)].enumerated() {
        let pt = NSPoint(x: s * CGFloat(p.0), y: s * CGFloat(p.1))
        i == 0 ? arrow.move(to: pt) : arrow.line(to: pt)
    }
    arrow.close()
    arrow.lineWidth = s * 0.085   // fat round joins turn every corner into a soft fingertip curve
    arrow.lineJoinStyle = .round
    NSColor.white.setFill()
    NSColor.white.setStroke()
    arrow.fill()
    arrow.stroke()

    let c = NSPoint(x: s * 0.29, y: s * 0.75)
    let spark = NSBezierPath()
    let big = s * 0.075, small = s * 0.019
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        let rr = i % 2 == 0 ? big : small
        let pt = NSPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
        i == 0 ? spark.move(to: pt) : spark.line(to: pt)
    }
    spark.close()
    NSColor(red: 1, green: 0.88, blue: 0.45, alpha: 1).setFill()
    spark.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
