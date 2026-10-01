import HandKit
import QuartzCore
import SwiftUI

/// Small ring at the cursor showing what the hand is about to do: it closes as
/// you pinch, so a click never comes as a surprise (Ultraleap-style affordance).
struct PointerHUD: View {
    let engine: HandEngine

    var body: some View {
        // The overlay covers the main display, whose coordinates match global ones.
        // ponytail: main display only; one HUD window per screen if multi-display matters.
        ZStack {
            if engine.gesture != .idle {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.35), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: engine.pinchProgress)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                    }
                }
                .frame(width: 30, height: 30)
                .background(Circle().fill(.black.opacity(0.25)))
                .position(x: engine.cursor.x + 22, y: engine.cursor.y + 22)
                .opacity(engine.gesture == .engaging ? 0.4 : 1)
                if engine.needsBreak {
                    Text("20 min of hand use. Lower your arm for 15 s.")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.45)))
                        .fixedSize()
                        .position(x: engine.cursor.x + 22, y: engine.cursor.y + 50)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var color: Color {
        if engine.isPaused { return .gray }
        switch engine.gesture {
        case .pressing, .dragging, .anchoredPressing: return .green
        case .scrolling, .rightPending: return .orange
        case .clutched: return .yellow
        default: return .accentColor
        }
    }

    private var symbol: String? {
        if engine.isPaused { return "pause.fill" }
        if let flick = engine.lastFlick, CACurrentMediaTime() - flick.time < 0.5 {
            return flick.direction == .up ? "chevron.up.2" : "chevron.down.2"
        }
        if engine.flickReady { return "chevron.up.chevron.down" }
        switch engine.gesture {
        case .dragging: return "hand.draw.fill"
        case .scrolling: return "arrow.up.and.down"
        case .clutched: return "hand.raised.slash.fill"
        default: return nil
        }
    }
}
