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
    NSGradient(colors: [NSColor(red: 0.98, green: 0.55, blue: 0.25, alpha: 1),
                        NSColor(red: 0.55, green: 0.12, blue: 0.35, alpha: 1)])!.draw(in: squircle, angle: -90)

    // Three overlapping translucent discs (eye, hand, voice); overlaps brighten toward the center.
    let r = s * 0.17
    let d = s * 0.105
    for angle in [90.0, 210.0, 330.0] {
        let a = CGFloat(angle) * .pi / 180
        let c = NSPoint(x: s * 0.5 + d * cos(a), y: s * 0.49 + d * sin(a))
        NSColor(white: 1, alpha: 0.58).setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
