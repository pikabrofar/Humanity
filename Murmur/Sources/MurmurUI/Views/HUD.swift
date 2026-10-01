import AppKit
import SwiftUI

/// Floating pill near the bottom of the screen. A non-activating panel, so
/// the app being dictated into keeps keyboard focus and receives the paste.
final class HUDPanel: NSPanel {
    private static let size = NSSize(width: 480, height: 72)

    init(content: some View) {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = NSHostingView(rootView: content.frame(width: Self.size.width, height: Self.size.height))
    }

    /// Shows on the screen with the pointer, where the user is looking.
    func present() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        setFrameOrigin(NSPoint(x: area.midX - Self.size.width / 2, y: area.minY + 40))
        orderFrontRegardless()
    }
}

struct HUDView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            leading.frame(width: 44)
            Text(message)
                .font(.callout)
                .foregroundStyle(model.partial.isEmpty || model.notice != nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.head) // keep the newest words visible
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.phase == .listening {
                Text("esc")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.tertiary))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.black.opacity(0.82), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        .padding(12)
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.15), value: model.phase)
    }

    @ViewBuilder private var leading: some View {
        switch model.phase {
        case .listening:
            HStack(spacing: 6) {
                RecordingIndicator()
                LevelBars(level: Double(model.level))
            }
        case .preparing, .finishing:
            ProgressView().controlSize(.small)
        case .idle:
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
    }

    private var message: String {
        if let notice = model.notice { return notice }
        switch model.phase {
        case .preparing: return "Starting…"
        case .finishing: return model.cleanup ? "Polishing…" : "Finishing…"
        default:
            if !model.partial.isEmpty { return model.partial }
            return model.mode == .note ? "Recording a note…" : "Listening…"
        }
    }
}

/// Five bars that grow with the input level, louder in the middle like a voice.
struct LevelBars: View {
    let level: Double
    private let shape: [Double] = [0.45, 0.75, 1, 0.75, 0.45]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(shape.indices, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: 4 + 16 * level * shape[i])
            }
        }
        .frame(height: 20)
        .animation(.linear(duration: 0.08), value: level)
    }
}
