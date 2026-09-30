import AppKit
import Carbon.HIToolbox
import GazeKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum SidebarSection: String, CaseIterable, Identifiable {
    case live, calibrate, recordings
    var id: Self { self }

    var title: String {
        switch self {
        case .live: "Live"
        case .calibrate: "Calibrate"
        case .recordings: "Recordings"
        }
    }

    var symbol: String {
        switch self {
        case .live: "eye"
        case .calibrate: "scope"
        case .recordings: "flame"
        }
    }
}

/// App-level state: overlay windows, recording, and the calibration lifecycle.
@MainActor @Observable
final class AppModel {
    let engine = GazeEngine()
    let recordings = RecordingStore()

    var section: SidebarSection? = .live
    var selectedRecordingID: Recording.ID?
    /// Display to calibrate on; defaults to the main display.
    var calibrationDisplayID: CGDirectDisplayID = NSScreen.main?.displayID ?? 0

    var showCursor = Defaults.bool(.showCursor, default: false) {
        didSet { Defaults.set(showCursor, .showCursor); updateCursorWindow() }
    }
    var cursorStyle = CursorStyle(rawValue: Defaults.string(.cursorStyle) ?? "") ?? .ring {
        didSet { Defaults.set(cursorStyle.rawValue, .cursorStyle); rebuildCursorWindow() }
    }
    var cursorSize = Defaults.double(.cursorSize, default: 44) {
        didSet { Defaults.set(cursorSize, .cursorSize); rebuildCursorWindow() }
    }
    var hideWhileRecording = Defaults.bool(.hideWhileRecording, default: false) {
        didSet { Defaults.set(hideWhileRecording, .hideWhileRecording) }
    }
    var captureScreenshot = Defaults.bool(.captureScreenshot, default: false) {
        didSet { Defaults.set(captureScreenshot, .captureScreenshot) }
    }
    var learnFromClicks = Defaults.bool(.learnFromClicks, default: true) {
        didSet { Defaults.set(learnFromClicks, .learnFromClicks) }
    }

    private(set) var activeRecording: ActiveRecording?
    private(set) var calibration: CalibrationController?

    var isRecording: Bool { activeRecording != nil }

    @ObservationIgnored private var cursorWindow: OverlayWindow?
    @ObservationIgnored private var calibrationWindow: OverlayWindow?
    @ObservationIgnored private var heatmapWindow: OverlayWindow?
    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var screenObserver: Any?
    @ObservationIgnored private var clickMonitors: [Any] = []

    init() {
        Task { await engine.start() }
        hotKey = HotKey(keyCode: kVK_ANSI_R, modifiers: cmdKey | optionKey) { [weak self] in
            MainActor.assumeIsolated { self?.toggleRecording() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildCursorWindow() }
        }
        // Mouse-button global monitors need no Accessibility permission (key monitors do).
        clickMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleClick() }
            } as Any,
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                MainActor.assumeIsolated { self?.handleClick() }
                return event
            } as Any,
        ]
        updateCursorWindow()
    }

    private func handleClick() {
        guard learnFromClicks, calibration == nil else { return }
        let frame = engine.targetScreen.frame
        let location = NSEvent.mouseLocation // global, origin bottom-left
        guard frame.contains(location) else { return }
        engine.learnFromClick(at: CGPoint(x: (location.x - frame.minX) / frame.width,
                                          y: 1 - (location.y - frame.minY) / frame.height))
    }

    // MARK: Gaze cursor

    private func updateCursorWindow() {
        let wanted = showCursor && engine.isCalibrated && calibration == nil
        if wanted, cursorWindow == nil {
            let window = OverlayWindow(
                screen: engine.targetScreen, interactive: false,
                content: GazeCursorView(engine: engine, style: cursorStyle, size: cursorSize)
            )
            window.present()
            cursorWindow = window
        } else if !wanted, let window = cursorWindow {
            window.close()
            cursorWindow = nil
        }
    }

    private func rebuildCursorWindow() {
        cursorWindow?.close()
        cursorWindow = nil
        updateCursorWindow()
    }

    // MARK: Calibration

    var calibrationScreen: NSScreen {
        NSScreen.withDisplayID(calibrationDisplayID) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func startCalibration() {
        guard calibration == nil else { return }
        stopRecording()
        closeHeatmapOverlay()

        let screen = calibrationScreen
        let controller = CalibrationController(engine: engine, screen: screen) { [weak self] in
            self?.endCalibration()
        }
        calibration = controller
        updateCursorWindow()

        let window = OverlayWindow(screen: screen, interactive: true,
                                   content: CalibrationOverlayView(controller: controller, engine: engine))
        window.present()
        calibrationWindow = window
        NSCursor.hide()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let controller = self.calibration else { return event }
            switch Int(event.keyCode) {
            case kVK_Escape:
                controller.close()
                return nil
            case kVK_Space where controller.phase == .intro:
                controller.begin()
                return nil
            default:
                return event
            }
        }
    }

    private func endCalibration() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        calibrationWindow?.close()
        calibrationWindow = nil
        calibration = nil
        NSCursor.unhide()
        rebuildCursorWindow() // the target screen may have changed
    }

    func clearCalibration() {
        engine.calibration = nil
        updateCursorWindow()
    }

    // MARK: Recording

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        guard !isRecording, engine.isCalibrated, calibration == nil else { return }
        let screen = engine.targetScreen
        activeRecording = ActiveRecording(screenSize: screen.frame.size)

        Task {
            if hideWhileRecording {
                NSApp.hide(nil)
                try? await Task.sleep(for: .milliseconds(350))
            }
            if captureScreenshot, isRecording {
                activeRecording?.screenshot = try? await ScreenshotCapture.capture(displayID: screen.displayID)
            }
            guard isRecording else { return }
            engine.gazeSink = { [weak self] sample in self?.activeRecording?.append(sample) }
        }
    }

    func stopRecording() {
        guard let active = activeRecording else { return }
        engine.gazeSink = nil
        activeRecording = nil

        guard active.samples.count > 10 else { return }
        let recording = Recording(
            name: active.startDate.formatted(date: .abbreviated, time: .shortened),
            date: active.startDate,
            duration: active.samples.last?.t ?? 0,
            screenSize: active.screenSize,
            samples: active.samples,
            hasScreenshot: false
        )
        recordings.add(recording, screenshot: active.screenshot)
        selectedRecordingID = recording.id
    }

    // MARK: Heatmap overlay

    func showHeatmapOverlay(_ recording: Recording) {
        closeHeatmapOverlay()
        let screen = NSScreen.screens.first { $0.frame.size == recording.screenSize } ?? engine.targetScreen
        let window = OverlayWindow(screen: screen, interactive: true,
                                   content: HeatmapOverlayView(recording: recording) { [weak self] in self?.closeHeatmapOverlay() })
        window.present()
        heatmapWindow = window

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Int(event.keyCode) == kVK_Escape, self?.heatmapWindow != nil else { return event }
            self?.closeHeatmapOverlay()
            return nil
        }
    }

    func closeHeatmapOverlay() {
        guard let window = heatmapWindow else { return }
        window.close()
        heatmapWindow = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    // MARK: Export

    func export(_ recording: Recording, as type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = recording.name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if type == .commaSeparatedText {
            try? recording.csv().write(to: url, atomically: true, encoding: .utf8)
        } else if let image = HeatmapExporter.render(recording, background: recordings.screenshot(for: recording)) {
            RecordingStore.writePNG(image, to: url)
        }
    }
}

/// Composites the heatmap over the screenshot (or a dark backdrop) at full resolution.
enum HeatmapExporter {
    static func render(_ recording: Recording, background: NSImage?) -> CGImage? {
        let size = recording.screenSize
        guard let heatmap = HeatmapRenderer.render(points: recording.samples.map(\.point), aspectRatio: recording.aspectRatio),
              let context = CGContext(
                data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        let rect = CGRect(origin: .zero, size: size)
        if let bg = background?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(bg, in: rect)
        } else {
            context.setFillColor(CGColor(gray: 0.1, alpha: 1))
            context.fill(rect)
        }
        context.interpolationQuality = .high
        context.draw(heatmap, in: rect)
        return context.makeImage()
    }
}
