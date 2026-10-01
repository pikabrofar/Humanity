// ponytail: Meter and RecordingIndicator copied from Murmur's Components.swift, which was
// itself copied from OculOS; extract a shared package.
import SwiftUI

/// Labeled horizontal meter for a value in 0...1.
struct Meter: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
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
