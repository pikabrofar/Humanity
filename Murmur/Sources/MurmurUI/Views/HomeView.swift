import MurmurKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Murmur").font(.largeTitle.weight(.semibold))
                    Text("Talk instead of typing, in any app. Speech is turned into text on this Mac.")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    StatusChip(text: Transcribers.engineName, symbol: "waveform")
                    StatusChip(text: Intelligence.isAvailable && model.useIntelligence ? "Apple Intelligence" : "Rule-based cleanup",
                               symbol: "sparkles", tint: Intelligence.isAvailable && model.useIntelligence ? .purple : .secondary)
                    StatusChip(text: model.canPaste ? "Auto-paste" : "Copy only", symbol: "doc.on.clipboard",
                               tint: model.canPaste ? .green : .orange)
                }

                Card(title: "Dictate anywhere", symbol: "keyboard") {
                    HStack(alignment: .center, spacing: 16) {
                        KeyCaps(keys: ["⌃", "⌥", "⌘", "D"])
                        VStack(alignment: .leading, spacing: 4) {
                            Text("**Tap** to start, tap again to finish. Or **hold** while you talk and let go.")
                            Text("Text appears where your cursor is. Esc cancels.").foregroundStyle(.secondary)
                        }
                    }
                    if model.hotKeyMissing {
                        Label("Another app already uses ⌃⌥⌘D. Use the menu bar icon instead.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).font(.caption)
                    }
                }

                Card(title: "Voice note", symbol: "record.circle") {
                    HStack(spacing: 16) {
                        Button { model.toggle(.note) } label: {
                            Label(model.isActive ? "Stop" : "Record a Note",
                                  systemImage: model.isActive ? "stop.fill" : "mic.fill")
                                .frame(minWidth: 130)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(model.isActive ? .red : .accentColor)
                        .controlSize(.large)
                        .disabled(model.phase == .finishing)

                        if model.phase == .listening {
                            VStack(alignment: .leading, spacing: 6) {
                                Meter(label: "Level", value: Double(model.level))
                                Text(model.partial.isEmpty ? "Listening…" : model.partial)
                                    .lineLimit(2, reservesSpace: true)
                                    .truncationMode(.head)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("For longer thoughts and meetings. Saved to the Library with a summary and action items.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Card(title: "Private by design", symbol: "lock.shield") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Speech recognition runs on this Mac. Audio is never uploaded.", systemImage: "checkmark")
                        Label("Cleanup and summaries use Apple's on-device model, or local rules.", systemImage: "checkmark")
                        Label("No account, no analytics, no screenshots. Recordings stay in Application Support.", systemImage: "checkmark")
                        Label("Pasted text is marked transient so clipboard managers skip it.", systemImage: "checkmark")
                    }
                    .foregroundStyle(.secondary)
                }

                if !model.recordings.isEmpty {
                    Card(title: "Recent", symbol: "clock") {
                        ForEach(model.recordings.prefix(4)) { recording in
                            Button {
                                model.selection = recording.id
                                model.section = .library
                            } label: {
                                RecordingRow(recording: recording).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Dictate")
    }
}

struct KeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.title3.weight(.medium))
                    .frame(minWidth: 30, minHeight: 30)
                    .background(.background, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                    .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
            }
        }
    }
}
