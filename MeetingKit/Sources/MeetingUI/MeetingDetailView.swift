import AppKit
import MeetingKit
import SwiftUI

/// Speaker-labeled transcript. Clicking a remote speaker's name renames every turn of
/// that voice. Saving the voice as a profile, so the next meeting recognizes them, is a
/// separate opt-in that needs the user's attestation that the person agreed.
public struct MeetingDetailView: View {
    @Binding var meeting: Meeting
    @ObservedObject var profiles: VoiceProfileStore

    @State private var renaming: TranscriptTurn? // the turn whose name was clicked
    @State private var newName = ""
    @State private var remember = false
    @State private var agreed = false
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
            if let callAudioNote {
                Text(callAudioNote).font(.caption).foregroundStyle(.orange).padding([.horizontal, .bottom], 10)
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

    /// Only your side was transcribed; say why rather than leave the call silently missing.
    private var callAudioNote: String? {
        let reasons = [meeting.recording.micError, meeting.recording.callAudioError].compactMap { $0 }
        if !reasons.isEmpty { return reasons.joined(separator: "\n") }
        let recorded = FileManager.default.fileExists(atPath: meeting.recording.systemURL.path)
        return recorded ? nil : "Call audio wasn't captured: no sound arrived from the call, so only your side is transcribed."
    }

    private func row(_ turn: TranscriptTurn) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if turn.speakerID == TranscriptAligner.localSpeakerID {
                    Text(turn.speakerName).bold()
                } else {
                    Button(turn.speakerName) {
                        newName = meeting.speakers[turn.speakerID]?.profileID == nil ? "" : turn.speakerName
                        remember = false
                        agreed = false
                        renaming = turn
                    }
                    .buttonStyle(.link)
                    .bold()
                    .help("Rename this speaker, and optionally remember their voice")
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
        let name = newName.trimmingCharacters(in: .whitespaces)
        let person = name.isEmpty ? "This person" : name
        let canRemember = renaming.map { meeting.diarization.centroids[$0.speakerID] != nil } ?? false
        return VStack(alignment: .leading, spacing: 8) {
            Text("Who is this?").font(.headline)
            TextField("Name", text: $newName).onSubmit(commitRename).frame(width: 260)
            if !profiles.profiles.isEmpty {
                Menu("Known voices") {
                    ForEach(profiles.profiles) { profile in
                        Button(profile.name) { newName = profile.name }
                    }
                }
                .fixedSize()
            }
            if canRemember {
                Toggle("Remember this voice for future meetings", isOn: $remember)
                if remember {
                    Text("This saves a voiceprint of \(person): biometric data, not audio. It stays on this Mac, is deleted after 12 months unused (3 years at most), and \(person) can ask you to delete it at any time. Some places, such as Illinois, require their written consent.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle("\(person) told me they agree to having their voiceprint saved on this Mac.", isOn: $agreed)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { renaming = nil }
                Button(remember ? "Save Name & Voice" : "Save Name", action: commitRename).keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || (remember && !agreed))
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private func commitRename() {
        guard let cluster = renaming?.speakerID, !newName.trimmingCharacters(in: .whitespaces).isEmpty,
              !remember || agreed else { return }
        do {
            try meeting.name(speaker: cluster, as: newName, rememberWithConsentAt: remember ? Date() : nil, in: profiles)
            try meeting.save()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        renaming = nil
    }
}
