import SwiftUI

enum CursorStyle: String, CaseIterable, Identifiable {
    case ring, dot, spotlight
    var id: Self { self }

    var label: String {
        switch self {
        case .ring: "Ring"
        case .dot: "Dot"
        case .spotlight: "Spotlight"
        }
    }
}

/// Click-through, full-screen gaze indicator.
struct GazeCursorView: View {
    let engine: GazeEngine
    let style: CursorStyle
    let size: Double

    var body: some View {
        GeometryReader { geo in
            if let gaze = engine.gaze {
                let point = CGPoint(x: gaze.x * geo.size.width, y: gaze.y * geo.size.height)
                ZStack {
                    switch style {
                    case .ring:
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                            .background(Circle().fill(Color.accentColor.opacity(0.12)))
                            .shadow(color: .black.opacity(0.35), radius: 3)
                            .frame(width: size, height: size)
                            .position(point)
                    case .dot:
                        Circle()
                            .fill(Color.accentColor.opacity(0.85))
                            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                            .shadow(color: .accentColor.opacity(0.6), radius: 8)
                            .frame(width: size / 2.5, height: size / 2.5)
                            .position(point)
                    case .spotlight:
                        ZStack {
                            Color.black.opacity(0.55)
                            Circle()
                                .fill(RadialGradient(colors: [.black, .black, .clear], center: .center,
                                                     startRadius: 0, endRadius: size * 3))
                                .frame(width: size * 6, height: size * 6)
                                .position(point)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                }
                // The stabilizer moves in discrete jumps; the spring renders them at display rate.
                .animation(.spring(response: 0.28, dampingFraction: 1), value: point)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: engine.gaze == nil)
        .allowsHitTesting(false)
    }
}
