import AppKit
import Carbon.HIToolbox
import GazeKit
import HandKit
import Observation
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case live, setup, practice
    var id: Self { self }

    var title: String {
        switch self {
        case .live: "Live"
        case .setup: "Quick Setup"
        case .practice: "Practice"
        }
    }

    var symbol: String {
        switch self {
        case .live: "hand.raised"
        case .setup: "checklist"
        case .practice: "target"
        }
    }
}

@MainActor @Observable
final class AppModel {
    let engine: HandEngine
    var section: SidebarSection? = Defaults.bool(.completedSetup, default: false) ? .live : .setup
    private(set) var canControl = Permissions.canControl

    var showHUD = Defaults.bool(.showHUD, default: true) {
        didSet { Defaults.set(showHUD, .showHUD); updateHUD() }
    }

    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var hudWindow: OverlayWindow?
    @ObservationIgnored private var permissionTimer: Timer?
    @ObservationIgnored private var terminationObserver: Any?

    init(camera: CameraCapture? = nil) {
        engine = HandEngine(camera: camera)
        Task { await engine.start() }
        // Kill switch: works from any app, even mid-drag.
        hotKey = HotKey(keyCode: kVK_ANSI_H, modifiers: controlKey | optionKey | cmdKey) { [weak self] in
            MainActor.assumeIsolated { self?.toggleControl() }
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.engine.release() }
        }
        // There's no callback when Accessibility is granted, so poll.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.canControl = Permissions.canControl }
        }
    }

    var isEnabled: Bool { engine.isEnabled }

    func toggleControl() {
        setControl(!engine.isEnabled)
    }

    func setControl(_ on: Bool) {
        guard !on || canControl else {
            Permissions.requestControl()
            section = .setup
            return
        }
        engine.isEnabled = on
        updateHUD()
        NSSound(named: on ? "Tink" : "Pop")?.play()
    }

    func completeSetup() {
        Defaults.set(true, .completedSetup)
        section = .practice
    }

    private func updateHUD() {
        let wanted = showHUD && engine.isEnabled
        if wanted, hudWindow == nil, let screen = NSScreen.screens.first {
            let window = OverlayWindow(screen: screen, interactive: false, content: PointerHUD(engine: engine))
            window.present()
            hudWindow = window
        } else if !wanted, let window = hudWindow {
            window.close()
            hudWindow = nil
        }
    }
}
