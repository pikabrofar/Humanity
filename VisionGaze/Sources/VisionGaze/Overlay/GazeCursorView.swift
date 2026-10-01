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
                Group {
                    if style == .spotlight {
                        SpotlightMask(center: gaze, size: size)
                    } else {
                        CursorMark(style: style, size: size).position(point)
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

/// The ring or dot drawn at the gaze point. A thin dark halo keeps it visible
/// on light content.
struct CursorMark: View {
    let style: CursorStyle
    let size: Double

    var body: some View {
        switch style {
        case .ring, .spotlight:
            Circle()
                .strokeBorder(Theme.signal, lineWidth: 2.5)
                .background(Circle().fill(Theme.signal.opacity(0.08)))
                .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
                .frame(width: size, height: size)
        case .dot:
            Circle()
                .fill(Theme.signal)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                .frame(width: size / 2.5, height: size / 2.5)
        }
    }
}

/// Dims everything except a soft circle around `center` (normalized).
struct SpotlightMask: View {
    let center: CGPoint
    let size: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.55)
                Circle()
                    .fill(RadialGradient(colors: [.black, .black, .clear], center: .center,
                                         startRadius: 0, endRadius: size * 3))
                    .frame(width: size * 6, height: size * 6)
                    .position(x: center.x * geo.size.width, y: center.y * geo.size.height)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}
