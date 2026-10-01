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

    // Squircle background, inset per macOS icon grid: near-black, barely graded.
    let inset = s * 0.1
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(colors: [NSColor(white: 0.13, alpha: 1), NSColor(white: 0.05, alpha: 1)])!.draw(in: squircle, angle: -90)
    NSColor(white: 1, alpha: 0.08).setStroke()
    squircle.lineWidth = max(1, s * 0.004)
    squircle.stroke()

    // Eye outline: a thin white almond.
    let c = NSPoint(x: s / 2, y: s / 2)
    let w = s * 0.58, h = s * 0.27
    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: c.x - w / 2, y: c.y))
    eye.curve(to: NSPoint(x: c.x + w / 2, y: c.y), controlPoint1: NSPoint(x: c.x - w / 4, y: c.y + h), controlPoint2: NSPoint(x: c.x + w / 4, y: c.y + h))
    eye.curve(to: NSPoint(x: c.x - w / 2, y: c.y), controlPoint1: NSPoint(x: c.x + w / 4, y: c.y - h), controlPoint2: NSPoint(x: c.x - w / 4, y: c.y - h))
    NSColor(white: 1, alpha: 0.92).setStroke()
    eye.lineWidth = s * 0.024
    eye.lineCapStyle = .round
    eye.stroke()

    // Iris in the app's signal orange, pupil, and a catchlight.
    func disc(_ center: NSPoint, _ r: CGFloat, _ color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)).fill()
    }
    disc(c, s * 0.1, NSColor(red: 1, green: 0.42, blue: 0.14, alpha: 1))
    disc(c, s * 0.042, NSColor(white: 0.05, alpha: 1))
    disc(NSPoint(x: c.x - s * 0.03, y: c.y + s * 0.032), s * 0.016, .white)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
