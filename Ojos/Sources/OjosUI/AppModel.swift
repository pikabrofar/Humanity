import AppKit
import Carbon.HIToolbox
import GazeKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum SidebarSection: String, CaseIterable, Identifiable {
    case setup, live, calibrate, recordings
    var id: Self { self }

    var title: String {
        switch self {
        case .setup: "Quick Setup"
        case .live: "Live"
        case .calibrate: "Calibrate"
        case .recordings: "Recordings"
        }
    }

    var symbol: String {
        switch self {
        case .setup: "checklist"
        case .live: "eye"
        case .calibrate: "scope"
        case .recordings: "flame"
        }
    }
}

/// App-level state: overlay windows, recording, and the calibration lifecycle.
@MainActor @Observable
final class AppModel {
    let engine: GazeEngine
    let recordings = RecordingStore()

    var section: SidebarSection? = Defaults.bool(.completedSetup, default: false) ? .live : .setup
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
    /// Gaze never clicks by itself unless this is on (research 07, 12, 13). Not
    /// persisted: every launch starts with dwell off, so clicks never resume unnoticed.
    var dwellClick = false {
        didSet { dwellProgress = 0; updateEscMonitors(); updateCursorWindow() }
    }
    /// Seconds, 0.3 … 3.
    var dwellTime = Defaults.double(.dwellTime, default: 1) {
        didSet { Defaults.set(dwellTime, .dwellTime) }
    }
    var snapToTargets = Defaults.bool(.snapToTargets, default: true) {
        didSet { Defaults.set(snapToTargets, .snapToTargets) }
    }
    private(set) var dwellProgress = 0.0

    private(set) var activeRecording: ActiveRecording?
    private(set) var calibration: CalibrationController?

    var isRecording: Bool { activeRecording != nil }

    @ObservationIgnored private var cursorWindow: OverlayWindow?
    @ObservationIgnored private var calibrationWindow: OverlayWindow?
    @ObservationIgnored private var heatmapWindow: OverlayWindow?
    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var clickHotKey: HotKey?
    @ObservationIgnored private var dwellHotKey: HotKey?
    @ObservationIgnored private var escMonitors: [Any] = []
    @ObservationIgnored private var dwell = Dwell()
    @ObservationIgnored private var screenObserver: Any?
    @ObservationIgnored private var clickMonitors: [Any] = []

    init(camera: CameraCapture? = nil) {
        engine = GazeEngine(camera: camera)
        Task { await engine.start() }
        hotKey = HotKey(keyCode: kVK_ANSI_R, modifiers: cmdKey | optionKey) { [weak self] in
            MainActor.assumeIsolated { self?.toggleRecording() }
        }
        clickHotKey = HotKey(keyCode: kVK_ANSI_G, modifiers: controlKey | optionKey | cmdKey) { [weak self] in
            MainActor.assumeIsolated { self?.clickAfterModifiersUp() }
        }
        dwellHotKey = HotKey(keyCode: kVK_ANSI_E, modifiers: controlKey | optionKey | cmdKey) { [weak self] in
            MainActor.assumeIsolated { self?.toggleDwell() }
        }
        engine.onGaze = { [weak self] in self?.updateDwell() }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildCursorWindow() }
        }
        // Mouse-button global monitors need no Accessibility permission (key monitors do).
        clickMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                MainActor.assumeIsolated { self?.handleClick(event) }
            } as Any,
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                MainActor.assumeIsolated { self?.handleClick(event) }
                return event
            } as Any,
        ]
        updateCursorWindow()
    }

    private func handleClick(_ event: NSEvent) {
        // Our own gaze clicks land where we predicted, so they teach nothing.
        guard learnFromClicks, calibration == nil,
              event.cgEvent?.getIntegerValueField(.eventSourceUserData) != GazeClick.tag else { return }
        let frame = engine.targetScreen.frame
        let location = NSEvent.mouseLocation // global, origin bottom-left
        guard frame.contains(location) else { return }
        engine.learnFromClick(at: CGPoint(x: (location.x - frame.minX) / frame.width,
                                          y: 1 - (location.y - frame.minY) / frame.height))
    }

    // MARK: Gaze click

    /// Gaze in global display points (top-left origin, as CGEvent uses).
    var gazePoint: CGPoint? {
        guard let gaze = engine.gaze, let top = NSScreen.screens.first?.frame.maxY else { return nil }
        let frame = engine.targetScreen.frame
        return CGPoint(x: frame.minX + gaze.x * frame.width, y: top - frame.maxY + gaze.y * frame.height)
    }

    /// Where a click would land: the gaze, snapped to the nearest control within
    /// about 4° for explicit clicks, 1.5° (and never onto `dwellAvoids` controls) for dwell.
    private func clickTarget(forDwell: Bool = false) -> CGPoint? {
        guard calibration == nil, let point = gazePoint else { return nil }
        guard snapToTargets, let ppd = engine.calibration?.pointsPerDegree else { return point }
        let degrees = forDwell ? GazeClick.dwellSnapDegrees : GazeClick.clickSnapDegrees
        return GazeClick.snap(point, radius: degrees * ppd, forDwell: forDwell) ?? point
    }

    /// Clicks where the user looks. False when not tracking.
    @discardableResult
    func click() -> Bool {
        guard let point = clickTarget() else { return false }
        GazeClick.click(at: point)
        return true
    }

    /// ⌃⌥⌘E: arms or disarms dwell from any app.
    func toggleDwell() {
        if dwellClick || engine.isCalibrated { dwellClick.toggle() }
    }

    /// Esc cancels a dwell in progress. Monitors observe without swallowing the key,
    /// so Esc still reaches the frontmost app (the global one needs Accessibility,
    /// which dwell clicking needs anyway).
    private func updateEscMonitors() {
        escMonitors.forEach(NSEvent.removeMonitor)
        escMonitors = []
        guard dwellClick else { return }
        let cancel: (NSEvent) -> Void = { [weak self] event in
            guard Int(event.keyCode) == kVK_Escape else { return }
            MainActor.assumeIsolated { self?.cancelDwell() }
        }
        escMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: cancel) as Any,
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { cancel($0); return $0 } as Any,
        ]
    }

    private func cancelDwell() {
        dwell.cancel()
        dwellProgress = 0
    }

    /// The hot key's modifiers would turn the click into a ⌘/⌃/⌥-click, so wait
    /// for their release (up to 1 s). The target is taken at the press.
    private func clickAfterModifiersUp() {
        guard let point = clickTarget() else { return }
        Task {
            for _ in 0..<50 where !NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
                try? await Task.sleep(for: .milliseconds(20))
            }
            GazeClick.click(at: point)
        }
    }

    private func updateDwell() {
        guard dwellClick, calibration == nil else { return }
        dwell.duration = dwellTime
        dwell.radius = engine.fixationRadius
        // Without Accessibility macOS drops the click; don't pretend it happened.
        if dwell.update(gazePoint, at: CACurrentMediaTime()), AXIsProcessTrusted(),
           let point = clickTarget(forDwell: true), !GazeClick.dwellBlocked(at: point) {
            GazeClick.click(at: point)
        }
        if dwellProgress != dwell.progress { dwellProgress = dwell.progress }
    }

    // MARK: Gaze cursor

    private func updateCursorWindow() {
        let wanted = (showCursor || dwellClick) && engine.isCalibrated && calibration == nil
        if wanted, cursorWindow == nil {
            let window = OverlayWindow(
                screen: engine.targetScreen, interactive: false,
                content: GazeCursorView(model: self, style: cursorStyle, size: cursorSize)
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
                activeRecording?.screenshot = try? await ScreenshotCapture.capture(displayID: screen.displayID,
                                                                                  scale: screen.backingScaleFactor)
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
        let bg = background?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        // Retina: the screenshot is in pixels; match it, or the main display's scale without one.
        let scale = bg.map { CGFloat($0.width) / recording.screenSize.width } ?? NSScreen.main?.backingScaleFactor ?? 1
        let size = CGSize(width: recording.screenSize.width * scale, height: recording.screenSize.height * scale)
        guard let heatmap = HeatmapRenderer.render(points: recording.samples.map(\.point), aspectRatio: recording.aspectRatio),
              let context = CGContext(
                data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        let rect = CGRect(origin: .zero, size: size)
        if let bg {
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
