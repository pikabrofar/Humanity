import HandKit
import QuartzCore
import SwiftUI

struct LiveView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ControlCard()
                HStack(alignment: .top, spacing: 16) {
                    CameraCard().frame(minWidth: 380)
                    VStack(spacing: 16) {
                        GestureCard()
                        PinchCard()
                    }
                    .frame(width: 280)
                }
                GestureGuide()
            }
            .padding(20)
        }
        .navigationTitle("Live")
        .animation(.default, value: engine.isEnabled)
    }
}

/// The big on/off switch, with the kill-switch hotkey front and center.
private struct ControlCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let on = model.engine.isEnabled
        HStack(spacing: 14) {
            Image(systemName: on ? "hand.point.up.left.fill" : "hand.raised.slash")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background((on ? Color.green : Color.accentColor).gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(on ? "Hand control is on" : "Hand control is off").font(.headline)
                if let reason = model.engine.blockedReason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                } else {
                    Text(model.canControl ? "Press ⌃⌥⌘H anytime to turn it on or off."
                                          : "ManOS needs Accessibility permission to move the pointer.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            Spacer()
            Button(on ? "Turn Off" : "Turn On") { model.toggleControl() }
                .buttonStyle(.borderedProminent)
                .tint(on ? .red : .accentColor)
                .controlSize(.large)
                .keyboardShortcut("h", modifiers: [.control, .option, .command])
        }
        .padding(14)
        .background((on ? Color.green : Color.accentColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder((on ? Color.green : Color.accentColor).opacity(0.25)))
    }
}

private struct CameraCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        ZStack {
            switch engine.cameraState {
            case .running:
                CameraPreview(session: engine.captureSession)
                SkeletonOverlay(hands: engine.hands, active: engine.activeHand, imageSize: engine.imageSize,
                                pinching: engine.gesture == .pressing || engine.gesture == .dragging)
            case .starting:
                ProgressView("Starting camera…")
            case .denied:
                VStack(spacing: 10) {
                    Image(systemName: "video.slash").font(.system(size: 34))
                    Text("Camera access needed").font(.headline)
                    Button("Open Privacy Settings") { SystemSettings.open(.camera) }
                }
                .foregroundStyle(.white)
            case .failed(let message):
                Text(message).foregroundStyle(.white).padding()
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            if engine.cameraState == .running {
                HStack(spacing: 6) {
                    StatusChip(text: String(format: "%.0f fps", engine.fps), symbol: "speedometer")
                    StatusChip(text: engine.activeHand == nil ? "No hand" : "Hand",
                               symbol: engine.activeHand == nil ? "hand.raised.slash" : "hand.raised.fill",
                               tint: engine.activeHand == nil ? .orange : .green)
                    if engine.yieldingToMouse {
                        StatusChip(text: "Mouse", symbol: "computermouse", tint: .yellow)
                    }
                    // Confirms a flick was detected, separately from whether it scrolled.
                    TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                        if let flick = engine.lastFlick, CACurrentMediaTime() - flick.time < 0.8 {
                            StatusChip(text: flick.direction == .up ? "Flick ↑" : "Flick ↓",
                                       symbol: "chevron.up.chevron.down", tint: .accentColor)
                        }
                    }
                }
                .padding(10)
            }
        }
    }
}

private struct GestureCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        Card(title: "Gesture", symbol: "hand.tap") {
            HStack(spacing: 12) {
                Image(systemName: symbol(engine))
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading) {
                    Text(title(engine)).font(.title3.weight(.semibold))
                    Text(engine.isEnabled ? "Controlling the pointer" : "Preview only")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func title(_ e: HandEngine) -> String {
        if e.isPaused { return "Paused" }
        return switch e.gesture {
        case .idle: "No hand"
        case .engaging: "Getting ready…"
        case .hovering: "Pointing"
        case .pressing: "Click"
        case .dragging: "Dragging"
        case .rightPending: "Right click?"
        case .scrolling: "Scrolling"
        case .clutched: "Anchored (pointer held)"
        case .anchoredPressing: "Anchored click"
        }
    }

    private func symbol(_ e: HandEngine) -> String {
        if e.isPaused { return "pause.circle" }
        return switch e.gesture {
        case .idle: "hand.raised.slash"
        case .engaging: "hand.raised"
        case .hovering: "hand.point.up.left"
        case .pressing: "hand.tap.fill"
        case .dragging: "hand.draw.fill"
        case .rightPending: "hand.tap"
        case .scrolling: "arrow.up.and.down.circle"
        case .clutched: "hand.raised.fingers.spread"
        case .anchoredPressing: "hand.tap.fill"
        }
    }
}

/// Live pinch distance against both thresholds, so users can see why a click did or didn't fire.
private struct PinchCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let engine = model.engine
        let profile = engine.profile
        Card(title: "Pinch", symbol: "hand.pinch") {
            let d = engine.activeHand?.indexPinch
            GeometryReader { geo in
                let maxD = 1.5
                let x = { (v: Double) in geo.size.width * min(v / maxD, 1) }
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Rectangle().fill(.green.opacity(0.35)).frame(width: x(profile.pinchEnter))
                    Rectangle().fill(.yellow.opacity(0.25)).frame(width: x(profile.pinchExit) - x(profile.pinchEnter))
                        .offset(x: x(profile.pinchEnter))
                    if let d {
                        Circle().fill(Color.accentColor).frame(width: 12, height: 12).offset(x: x(d) - 6)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            HStack {
                Text("Click").foregroundStyle(.green)
                Spacer()
                Text(d.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                Spacer()
                Text("Open")
            }
            .font(.caption)
        }
    }
}

private struct GestureGuide: View {
    var body: some View {
        Card(title: "Gestures", symbol: "questionmark.circle") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    row("hand.point.up.left", "Move your palm", "Move the pointer")
                    row("hand.pinch", "Pinch thumb + index", "Click · hold and move to drag")
                }
                GridRow {
                    row("hand.tap", "Pinch thumb + middle", "Right-click · hold and move to scroll")
                    row("hand.raised.fingers.spread", "Make a fist", "Hold the pointer while you reposition")
                }
                GridRow {
                    row("hand.point.up.left.and.text", "Curl 3 fingers, pinch thumb + index", "Click without moving the pointer")
                }
                GridRow {
                    row("chevron.up.2", "Flick up / down", "Next / previous video, page or slide")
                    row("pause.circle", "Spread hand, hold still 1.5 s", "Pause or resume")
                }
                GridRow {
                    row("keyboard", "⌃⌥⌘H", "Turn hand control on or off")
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
            }
        }
    }

    private func row(_ symbol: String, _ gesture: String, _ action: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(gesture).font(.callout.weight(.medium))
                Text(action).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum SystemSettings {
    enum Pane: String {
        case camera = "Privacy_Camera"
        case accessibility = "Privacy_Accessibility"
    }

    static func open(_ pane: Pane) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)")!)
    }
}
