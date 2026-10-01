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

    // Open hand: rounded-rect palm, four fingers and an angled thumb.
    NSColor.white.setFill()
    let palm = NSRect(x: s * 0.375, y: s * 0.24, width: s * 0.2695, height: s * 0.28)
    NSBezierPath(roundedRect: palm, xRadius: s * 0.08, yRadius: s * 0.08).fill()
    let fw = s * 0.058
    for (i, top) in [0.65, 0.71, 0.69, 0.62].enumerated() {
        let x = s * 0.375 + CGFloat(i) * s * 0.0705
        let finger = NSRect(x: x, y: s * 0.36, width: fw, height: s * CGFloat(top) - s * 0.36)
        NSBezierPath(roundedRect: finger, xRadius: fw / 2, yRadius: fw / 2).fill()
    }
    let thumb = NSBezierPath(roundedRect: NSRect(x: -fw / 2, y: 0, width: fw * 1.1, height: s * 0.24),
                             xRadius: fw / 2, yRadius: fw / 2)
    let t = AffineTransform(translationByX: s * 0.43, byY: s * 0.29)
    var r = AffineTransform(rotationByDegrees: 38)
    r.append(t)
    thumb.transform(using: r)
    thumb.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
