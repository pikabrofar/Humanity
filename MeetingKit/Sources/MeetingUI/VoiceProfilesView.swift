import MeetingKit
import SwiftUI

/// Saved voices: rename, merge duplicates of one person, delete.
public struct VoiceProfilesView: View {
    @ObservedObject var store: VoiceProfileStore
    @State private var selection = Set<UUID>()
    @State private var error: String?

    public init(store: VoiceProfileStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.profiles.isEmpty {
                Text("No saved voices yet. Name a speaker in a meeting transcript to add one.")
                    .font(.callout).foregroundStyle(.secondary).padding(12)
            } else {
                List(selection: $selection) {
                    ForEach(store.profiles) { profile in
                        ProfileRow(profile: profile) { try store.rename(profile.id, to: $0) }
                            .tag(profile.id)
                            .contextMenu {
                                Button("Delete", role: .destructive) { run { try store.delete(profile.id) } }
                            }
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack(spacing: 8) {
                Button("Merge") {
                    // The oldest-saved selected profile survives and keeps its name.
                    let ids = store.profiles.map(\.id).filter(selection.contains)
                    if let target = ids.first { run { try store.merge(ids, into: target) } }
                    selection = []
                }
                .disabled(selection.count < 2)
                .help("Combine the selected profiles into one person")
                Button("Delete", role: .destructive) {
                    run { for id in selection { try store.delete(id) } }
                    selection = []
                }
                .disabled(selection.isEmpty)
                Spacer()
                if let error { Text(error).font(.caption).foregroundStyle(.red).lineLimit(1) }
            }
            .controlSize(.small)
            .padding(8)
            Text("Only voice fingerprints are saved, never audio. Stored on this Mac.")
                .font(.caption2).foregroundStyle(.tertiary).padding([.horizontal, .bottom], 8)
        }
        .frame(minWidth: 260, minHeight: 200)
    }

    private func run(_ action: () throws -> Void) {
        do { try action(); error = nil } catch { self.error = error.localizedDescription }
    }
}

private struct ProfileRow: View {
    let profile: VoiceProfile
    let rename: (String) throws -> Void
    @State private var name = ""

    var body: some View {
        HStack {
            TextField("Name", text: $name)
                .textFieldStyle(.plain)
                .onSubmit { if !name.trimmingCharacters(in: .whitespaces).isEmpty { try? rename(name) } }
            Spacer()
            Text("\(profile.embeddings.count) sample\(profile.embeddings.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { name = profile.name }
        .onChange(of: profile.name) { name = profile.name }
    }
}
