// ponytail: copied from VisionGaze; move to a shared package when a third app needs it.
import AppKit
import SwiftUI

/// A borderless, transparent window covering an entire screen, above all other
/// windows (including full-screen apps).
final class OverlayWindow: NSWindow {
    private let interactive: Bool

    init(screen: NSScreen, interactive: Bool, content: some View) {
        self.interactive = interactive
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = !interactive
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = NSHostingView(rootView: content.ignoresSafeArea())
    }

    // Borderless windows refuse key status by default; interactive overlays need
    // it for keyboard shortcuts.
    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { interactive }

    func present() {
        if interactive {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        } else {
            orderFrontRegardless()
        }
    }
}
