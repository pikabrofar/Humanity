#if DEBUG
import AppKit
import GazeKit
import SwiftUI

/// Renders every screen with canned data, writes PNG screenshots and quits.
/// CI runs it as `VISIONGAZE_SHOWCASE=<dir> .build/debug/VisionGaze` so UI
/// changes can be reviewed without a camera. Nothing is read from or written
/// to the user's calibration or recordings, and the camera is never started.
@MainActor
enum Showcase {
    static let directory = ProcessInfo.processInfo.environment["VISIONGAZE_SHOWCASE"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
    static var isActive: Bool { directory != nil }

    static func run(_ model: AppModel, openSettings: OpenSettingsAction) async {
        guard let directory, !started else { return }
        started = true
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSApp.activate(ignoringOtherApps: true)

        let calibration = makeCalibration()
        var screenshots: [UUID: NSImage] = [:]
        let recordings = makeRecordings().map { recording, screenshot in
            screenshots[recording.id] = screenshot
            return recording
        }
        model.recordings.showcase(recordings, screenshots: screenshots)
        model.selectedRecordingID = recordings.first?.id
        showLiveState(model, calibration: calibration)

        await settle(1)
        guard let window = NSApp.windows.first(where: { $0.title == "VisionGaze" && $0.isVisible }) else {
            log("main window not found")
            NSApp.terminate(nil)
            return
        }
        window.setContentSize(NSSize(width: 1120, height: 720))
        window.center()

        for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            NSApp.appearance = NSAppearance(named: appearance)
            for section in AppSection.allCases {
                model.section = section
                await settle(1.2)
                capture(window, "\(section.rawValue)-\(suffix)")
            }
        }

        // First run: no calibration yet.
        NSApp.appearance = NSAppearance(named: .aqua)
        model.engine.showcase(calibration: nil)
        model.section = .live
        await settle(1)
        capture(window, "live-uncalibrated-light")
        model.section = .calibrate
        await settle(1)
        capture(window, "calibrate-uncalibrated-light")
        model.engine.showcase(calibration: calibration, gaze: CGPoint(x: 0.58, y: 0.42))

        // Settings, one tab at a time.
        for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            NSApp.appearance = NSAppearance(named: appearance)
            openSettings()
            await settle(1.2)
            let settings = NSApp.windows.first { $0.isVisible && $0 !== window && $0.styleMask.contains(.titled) }
            if settings == nil {
                log("settings window not found; windows: " + NSApp.windows
                    .map { "\($0.title) \(Int($0.frame.width))x\(Int($0.frame.height)) visible=\($0.isVisible)" }
                    .joined(separator: "; "))
            }
            for tab in SettingsTab.allCases {
                UserDefaults.standard.set(tab.rawValue, forKey: "settingsTab")
                await settle(1)
                if let settings { capture(settings, "settings-\(tab.rawValue)-\(suffix)") }
            }
            settings?.close()
        }

        // Full-screen calibration: intro and results.
        model.startCalibration()
        await settle(1.5)
        if let overlay = NSApp.windows.first(where: { $0 is OverlayWindow && $0.isVisible }), let controller = model.calibration {
            capture(overlay, "calibration-intro")
            if let calibration { controller.showcaseResults(calibration) }
            await settle(1.2)
            capture(overlay, "calibration-results")
            controller.close()
        }

        await settle(0.5)
        NSApp.terminate(nil)
    }

    private static var started = false

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("Showcase: \(message)\n".utf8))
    }

    private static func settle(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: Capture

    private static func capture(_ window: NSWindow, _ name: String) {
        guard let directory else { return }
        // The window server's image includes the title bar and materials.
        if let image = windowImage(window) {
            RecordingStore.writePNG(image, to: directory.appendingPathComponent("\(name).png"))
        } else if let view = window.contentView?.superview ?? window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// `CGWindowListCreateImage`, looked up at runtime because newer SDKs mark it
    /// unavailable. Capturing your own windows needs no screen-recording permission.
    private static func windowImage(_ window: NSWindow) -> CGImage? {
        typealias Create = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") else { return nil }
        let create = unsafeBitCast(symbol, to: Create.self)
        let includingWindow: UInt32 = 1 << 3, boundsIgnoreFraming: UInt32 = 1 << 0, bestResolution: UInt32 = 1 << 3
        return create(.null, includingWindow, UInt32(window.windowNumber), boundsIgnoreFraming | bestResolution)?
            .takeRetainedValue()
    }

    // MARK: Canned data

    private static func showLiveState(_ model: AppModel, calibration: StoredCalibration?) {
        let left = ellipse(center: CGPoint(x: 0.546, y: 0.6), width: 0.05, height: 0.019)
        let right = ellipse(center: CGPoint(x: 0.454, y: 0.6), width: 0.05, height: 0.019)
        let landmarks = FaceLandmarksSnapshot(
            faceBounds: CGRect(x: 0.385, y: 0.24, width: 0.23, height: 0.52),
            leftEye: left, rightEye: right,
            leftPupil: CGPoint(x: 0.543, y: 0.601), rightPupil: CGPoint(x: 0.451, y: 0.601)
        )
        let features = GazeFeatures(
            timestamp: 0,
            left: EyeFeatures(pupil: CGPoint(x: 0.56, y: 0.02), openness: 0.31),
            right: EyeFeatures(pupil: CGPoint(x: 0.53, y: 0.02), openness: 0.30),
            yaw: 0.05, pitch: -0.07, roll: 0.02,
            faceCenter: CGPoint(x: 0.5, y: 0.5), faceSize: 0.23, isBlinking: false
        )
        var rng = SplitMix(seed: 3)
        let trail = (0..<20).map { i -> CGPoint in
            let t = Double(i) / 19
            return CGPoint(x: 0.28 + 0.36 * t + rng.noise(0.01), y: 0.58 - 0.22 * t + rng.noise(0.01))
        }
        model.engine.showcase(calibration: calibration, features: features, landmarks: landmarks,
                              gaze: CGPoint(x: 0.64, y: 0.36), trail: trail)
    }

    private static func ellipse(center: CGPoint, width: CGFloat, height: CGFloat) -> [CGPoint] {
        (0..<12).map { i in
            let a = Double(i) / 12 * 2 * .pi
            return CGPoint(x: center.x + width / 2 * cos(a), y: center.y + height / 2 * sin(a) * (sin(a) > 0 ? 1 : 0.7))
        }
    }

    /// Decoded from JSON because `GazeCalibration` has no public initializer.
    private static func makeCalibration() -> StoredCalibration? {
        var rng = SplitMix(seed: 7)
        func point(_ target: [Double], spread: Double) -> [String: Any] {
            let dx = rng.noise(spread), dy = rng.noise(spread)
            return ["target": target, "predicted": [target[0] + dx, target[1] + dy],
                    "error": (dx * dx + dy * dy).squareRoot() + spread * 0.5]
        }
        let grid = [0.08, 0.5, 0.92].flatMap { y in [0.08, 0.5, 0.92].map { x in [x, y] } }
        let validation = [[0.25, 0.25], [0.75, 0.25], [0.5, 0.4], [0.25, 0.75], [0.75, 0.75]]
        // Parameter layout of GazeCalibration.P: eye polynomials, yaw, pitch, cameraX, gap, scale, CNN terms.
        var params = [Double](repeating: 0, count: 20)
        params[11] = 0.92
        params[12] = 0.88
        params[13] = 0.5
        params[14] = 8
        params[15] = 1.04
        let screen = NSScreen.main
        let json: [String: Any] = [
            "model": [
                "geometry": ["widthMM": 302.0, "heightMM": 196.0, "imageAspect": 16.0 / 9, "cameraFOV": 72 * Double.pi / 180],
                "params": params,
                "featureMean": [0.5, 0.0, 0.3],
                "appearance": ["mean": [0.0, 0.0], "weights": [[0.0, 0.0], [0.0, 0.0]], "ridge": 10.0] as [String: Any],
                "report": ["points": grid.map { point($0, spread: 0.012) }, "rmsError": 0.021,
                           "meanDistanceMM": 584.0] as [String: Any],
                "createdAt": Date().timeIntervalSinceReferenceDate - 3600,
            ] as [String: Any],
            "samples": [Any](),
            "clickSamples": [Any](),
            "validation": ["accuracyDegrees": 1.7, "precisionDegrees": 0.6,
                           "points": validation.map { point($0, spread: 0.02) }] as [String: Any],
            "displayID": Int(screen?.displayID ?? 1),
            "displayName": screen?.localizedName ?? "Built-in Retina Display",
            "screenSize": [1512.0, 982.0],
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            return try JSONDecoder().decode(StoredCalibration.self, from: data)
        } catch {
            log("calibration failed to decode: \(error)")
            return nil
        }
    }

    /// A reading session over a mock web page, plus two without screenshots.
    private static func makeRecordings() -> [(Recording, NSImage?)] {
        let size = CGSize(width: 1512, height: 982)
        let base = Date().addingTimeInterval(-86_400)
        var rng = SplitMix(seed: 11)
        var reading: [CGPoint] = []
        for line in 0..<9 {
            let y = 0.3 + Double(line) * 0.052
            for word in 0..<7 { reading.append(CGPoint(x: 0.1 + Double(word) * 0.075, y: y)) }
        }
        reading += [CGPoint(x: 0.78, y: 0.36), CGPoint(x: 0.82, y: 0.42), CGPoint(x: 0.76, y: 0.47), CGPoint(x: 0.3, y: 0.16)]

        func samples(_ fixations: [CGPoint]) -> [GazeSample] {
            var out: [GazeSample] = []
            var t = 0.0
            for f in fixations {
                for _ in 0..<(6 + Int(abs(rng.noise(4)))) {
                    out.append(GazeSample(t: t, x: f.x + rng.noise(0.006), y: f.y + rng.noise(0.006)))
                    t += 1.0 / 30
                }
            }
            return out
        }
        func recording(_ name: String, _ hoursAgo: Double, _ fixations: [CGPoint]) -> Recording {
            let s = samples(fixations)
            return Recording(name: name, date: base.addingTimeInterval(-hoursAgo * 3600), duration: s.last?.t ?? 0,
                             screenSize: size, samples: s, hasScreenshot: false)
        }

        var first = recording("Reading the docs", 0, reading)
        first.hasScreenshot = true
        let scattered = (0..<40).map { _ in CGPoint(x: 0.5 + rng.noise(0.25), y: 0.45 + rng.noise(0.2)) }
        return [
            (first, mockPage(size)),
            (recording("Landing page review", 5, scattered), nil),
            (recording("Inbox triage", 26, Array(reading.reversed())), nil),
        ]
    }

    /// A stand-in screenshot: a plain article layout.
    private static func mockPage(_ size: CGSize) -> NSImage {
        NSImage(size: size, flipped: true) { rect in
            NSColor(white: 0.98, alpha: 1).setFill()
            rect.fill()
            NSColor(white: 0.93, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: size.width, height: 64).fill()
            NSColor(white: 0.2, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 120, y: 150, width: 640, height: 26), xRadius: 6, yRadius: 6).fill()
            NSColor(white: 0.78, alpha: 1).setFill()
            for line in 0..<9 {
                let y = (0.3 + Double(line) * 0.052) * size.height - 5
                let width = line == 8 ? 380.0 : 780.0
                NSBezierPath(roundedRect: NSRect(x: 120, y: y, width: width, height: 10), xRadius: 5, yRadius: 5).fill()
            }
            NSColor(white: 0.88, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 1080, y: 300, width: 320, height: 200), xRadius: 12, yRadius: 12).fill()
            return true
        }
    }
}

/// Deterministic noise for canned data.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }

    /// Roughly normal, with the given standard deviation.
    mutating func noise(_ sigma: Double) -> Double {
        ((0..<4).map { _ in next() }.reduce(0, +) - 2) * sigma * 1.7
    }
}
#endif
