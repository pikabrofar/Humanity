// ponytail: copied from VisionGaze; move to a shared package when a third app needs it.
import SwiftUI

/// Rounded, subtly filled container used throughout the main window.
struct Card<Content: View>: View {
    var title: String?
    var symbol: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label {
                    Text(title)
                } icon: {
                    if let symbol { Image(systemName: symbol).foregroundStyle(Color.accentColor) }
                }
                .font(.headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator.opacity(0.6)))
    }
}

/// Small status capsule, e.g. "30 fps" or "Face".
struct StatusChip: View {
    let text: String
    let symbol: String
    var tint: Color = .secondary

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium).monospacedDigit())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

/// Labeled horizontal meter for a value in 0...1.
struct Meter: View {
    let label: String
    let value: Double
    var display: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                if let display { Text(display).monospacedDigit() }
            }
            .font(.caption)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.accentColor.gradient)
                        .frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 5)
        }
    }
}

/// Pulsing red dot for recording state.
struct RecordingIndicator: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
            .opacity(pulse ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

extension TimeInterval {
    var clockString: String {
        let total = Int(self)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
