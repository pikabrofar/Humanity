import SwiftUI

/// A short practice course. ManOS's events hit it like any other app, so it
/// exercises the real pipeline: click targets, drag a card, scroll a list.
struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @State private var target = CGPoint(x: 0.5, y: 0.5)
    @State private var hits = 0
    @State private var started = Date()
    @State private var times: [TimeInterval] = []
    @State private var cardOffset = CGSize.zero
    @State private var dragBase = CGSize.zero
    @State private var dropped = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !model.engine.isEnabled {
                    Label("Turn hand control on (⌃⌥⌘H) to practice.", systemImage: "hand.raised")
                        .foregroundStyle(.orange)
                }
                Card(title: "1 · Click the targets", symbol: "target") {
                    GeometryReader { geo in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(.quinary)
                            Button {
                                times.append(Date().timeIntervalSince(started))
                                hits += 1
                                started = Date()
                                target = CGPoint(x: .random(in: 0.1...0.9), y: .random(in: 0.15...0.85))
                            } label: {
                                Circle().fill(Color.accentColor.gradient)
                                    .overlay(Circle().fill(.white).frame(width: 10, height: 10))
                                    .frame(width: max(64 - CGFloat(hits) * 4, 28), height: max(64 - CGFloat(hits) * 4, 28))
                            }
                            .buttonStyle(.plain)
                            .position(x: target.x * geo.size.width, y: target.y * geo.size.height)
                            .animation(.snappy, value: target)
                        }
                    }
                    .frame(height: 260)
                    HStack {
                        Text("Hits: \(hits)")
                        Spacer()
                        if !times.isEmpty {
                            Text(String(format: "Average %.1f s", times.reduce(0, +) / Double(times.count)))
                        }
                    }
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                Card(title: "2 · Drag the card into the box", symbol: "hand.draw") {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(dropped ? Color.green : .secondary, style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(width: 140, height: 90)
                            .overlay(Text(dropped ? "Nice!" : "Drop here").foregroundStyle(.secondary))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.gradient)
                            .frame(width: 120, height: 76)
                            .overlay(Image(systemName: "hand.draw.fill").font(.title).foregroundStyle(.white))
                            .offset(cardOffset)
                            .gesture(DragGesture()
                                .onChanged { cardOffset = CGSize(width: dragBase.width + $0.translation.width,
                                                                 height: dragBase.height + $0.translation.height) }
                                .onEnded { _ in
                                    dragBase = cardOffset
                                    dropped = cardOffset.width > 250
                                })
                    }
                    .frame(height: 110)
                }

                Card(title: "3 · Scroll to the highlighted row", symbol: "arrow.up.and.down") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(1...60, id: \.self) { i in
                                Text(i == 45 ? "Row \(i) — you made it!" : "Row \(i)")
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(i == 45 ? Color.green.opacity(0.3) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .frame(height: 180)
                }
            }
            .padding(20)
        }
        .navigationTitle("Practice")
    }
}
