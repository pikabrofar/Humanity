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

    // Squircle background, inset per macOS icon grid.
    let inset = s * 0.1
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.10, green: 0.12, blue: 0.24, alpha: 1),
                        NSColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1)])!.draw(in: squircle, angle: -90)

    // Heatmap glow.
    let c = NSPoint(x: s / 2, y: s / 2)
    NSGradient(colors: [NSColor(red: 1, green: 0.35, blue: 0.2, alpha: 0.9),
                        NSColor(red: 1, green: 0.8, blue: 0.1, alpha: 0.5),
                        NSColor(red: 0.1, green: 0.6, blue: 1, alpha: 0)])!
        .draw(fromCenter: c, radius: 0, toCenter: c, radius: s * 0.3, options: [])

    // Eye outline.
    let w = s * 0.56, h = s * 0.3
    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: c.x - w / 2, y: c.y))
    eye.curve(to: NSPoint(x: c.x + w / 2, y: c.y), controlPoint1: NSPoint(x: c.x - w / 4, y: c.y + h), controlPoint2: NSPoint(x: c.x + w / 4, y: c.y + h))
    eye.curve(to: NSPoint(x: c.x - w / 2, y: c.y), controlPoint1: NSPoint(x: c.x + w / 4, y: c.y - h), controlPoint2: NSPoint(x: c.x - w / 4, y: c.y - h))
    NSColor.white.setStroke()
    eye.lineWidth = s * 0.028
    eye.stroke()

    // Iris + pupil.
    let r = s * 0.085
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()
    NSColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1).setFill()
    let p = r * 0.45
    NSBezierPath(ovalIn: NSRect(x: c.x - p, y: c.y - p, width: 2 * p, height: 2 * p)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
