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

    // Abstract figure with open arms: round head + rounded strokes.
    NSColor.white.setFill()
    let hr = s * 0.072
    NSBezierPath(ovalIn: NSRect(x: s * 0.5 - hr, y: s * 0.66 - hr, width: 2 * hr, height: 2 * hr)).fill()
    let figure = NSBezierPath()
    figure.move(to: NSPoint(x: s * 0.29, y: s * 0.60))   // left hand
    figure.line(to: NSPoint(x: s * 0.5, y: s * 0.52))    // shoulders
    figure.line(to: NSPoint(x: s * 0.71, y: s * 0.60))   // right hand
    figure.move(to: NSPoint(x: s * 0.5, y: s * 0.52))
    figure.line(to: NSPoint(x: s * 0.5, y: s * 0.40))    // torso
    figure.line(to: NSPoint(x: s * 0.38, y: s * 0.25))   // left leg
    figure.move(to: NSPoint(x: s * 0.5, y: s * 0.40))
    figure.line(to: NSPoint(x: s * 0.62, y: s * 0.25))   // right leg
    figure.lineWidth = s * 0.075
    figure.lineCapStyle = .round
    figure.lineJoinStyle = .round
    NSColor.white.setStroke()
    figure.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
