import AppKit
import ScreenCaptureKit

/// Captures a still of a display, excluding ojoS's own windows, to use as
/// the backdrop for a recording's heatmap. Requires Screen Recording permission.
enum ScreenshotCapture {
    /// - Parameter scale: The screen's `backingScaleFactor`; SCDisplay sizes are in points.
    static func capture(displayID: CGDirectDisplayID, scale: CGFloat) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
