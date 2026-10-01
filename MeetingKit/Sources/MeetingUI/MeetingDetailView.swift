import AppKit
import MeetingKit
import SwiftUI

/// Speaker-labeled transcript. Clicking a remote speaker's name renames every turn of
/// that voice and saves it as a profile, so the next meeting recognizes them.
public struct MeetingDetailView: View {
    @Binding var meeting: Meeting
    @ObservedObject var profiles: VoiceProfileStore

    @State private var renaming: TranscriptTurn? // the turn whose name was clicked
    @State private var newName = ""
    @State private var error: String?

    public init(meeting: Binding<Meeting>, profiles: VoiceProfileStore) {
        _meeting = meeting
        self.profiles = profiles
    }

    public var body: some View {
        let transcript = meeting.transcript
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting.recording.title).font(.headline)
                    Text(meeting.recording.startedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Copy Markdown") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcript.markdown(title: meeting.recording.title), forType: .string)
                }
                .controlSize(.small)
            }
            .padding(10)
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 10)
            }
            Divider()
            if transcript.turns.isEmpty {
                Text("No speech was recognized.").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(transcript.turns) { turn in
                    row(turn)
                }
                .listStyle(.plain)
            }
        }
    }

    private func row(_ turn: TranscriptTurn) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if turn.speakerID == TranscriptAligner.localSpeakerID {
                    Text(turn.speakerName).bold()
                } else {
                    Button(turn.speakerName) {
                        newName = meeting.speakers[turn.speakerID]?.profileID == nil ? "" : turn.speakerName
                        renaming = turn
                    }
                    .buttonStyle(.link)
                    .bold()
                    .help("Rename this speaker and remember their voice")
                    .popover(isPresented: Binding(get: { renaming?.id == turn.id },
                                                  set: { if !$0 { renaming = nil } })) {
                        renameForm
                    }
                }
                Text(MeetingTranscript.timestamp(turn.start)).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }
            Text(turn.text).textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private var renameForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who is this?").font(.headline)
            TextField("Name", text: $newName).onSubmit(commitRename).frame(width: 200)
            if !profiles.profiles.isEmpty {
                Menu("Known voices") {
                    ForEach(profiles.profiles) { profile in
                        Button(profile.name) { newName = profile.name; commitRename() }
                    }
                }
                .fixedSize()
            }
            HStack {
                Spacer()
                Button("Cancel") { renaming = nil }
                Button("Save", action: commitRename).keyboardShortcut(.defaultAction)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(12)
    }

    private func commitRename() {
        guard let cluster = renaming?.speakerID else { return }
        do {
            try meeting.name(speaker: cluster, as: newName, in: profiles)
            try meeting.save()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        renaming = nil
    }
}
