import AIKit
import AppKit
import MeetingKit
import MeetingUI
import MurmurKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// Summary saved next to a meeting's audio, so it survives relaunches.
struct MeetingSummary: Codable, Equatable {
    var text: String
    var actionItems: [String]
    /// "Name: what they covered", when the model attributed points to speakers.
    var speakers: [String]
}

/// Meetings: record a call, separate speakers, name them once (voice profiles
/// remember them), and summarize.
@MainActor @Observable
final class MeetingsModel {
    @ObservationIgnored let recorder = MeetingRecorder()
    @ObservationIgnored let profiles = VoiceProfileStore()
    private(set) var meetings: [Meeting] = []
    private(set) var summaries: [UUID: MeetingSummary] = [:]
    private(set) var processing: Set<UUID> = []
    private(set) var summarizing: Set<UUID> = []
    var selection: UUID?
    var error: String?

    init() { reload() }

    func reload() {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: MeetingRecording.defaultDirectory, includingPropertiesForKeys: nil)) ?? []
        meetings = folders.compactMap { try? Meeting.load(from: $0) }
            .sorted { $0.recording.startedAt > $1.recording.startedAt }
        for meeting in meetings {
            if let data = try? Data(contentsOf: summaryURL(meeting)),
               let summary = try? JSONDecoder().decode(MeetingSummary.self, from: data) {
                summaries[meeting.id] = summary
            }
        }
    }

    /// Diarize, transcribe and match voices after the call ends (offline, on this Mac).
    func process(_ recording: MeetingRecording) async {
        processing.insert(recording.id)
        defer { processing.remove(recording.id) }
        do {
            let meeting = try await MeetingProcessor().process(recording, profiles: profiles)
            try meeting.save()
            meetings.insert(meeting, at: 0)
            selection = meeting.id
            await summarize(meeting.id)
        } catch {
            self.error = "Couldn't process the meeting: \(error.localizedDescription)"
        }
    }

    func binding(for id: UUID) -> Binding<Meeting>? {
        guard let initial = meetings.first(where: { $0.id == id }) else { return nil }
        // Falls back to the last known value, not meetings[0]: after a delete the list may be empty.
        return Binding(
            get: { self.meetings.first { $0.id == id } ?? initial },
            set: { updated in
                guard let i = self.meetings.firstIndex(where: { $0.id == id }) else { return }
                self.meetings[i] = updated
                try? updated.save()
            })
    }

    /// The provider chosen in AI Providers, else Apple Intelligence, else key sentences.
    func summarize(_ id: UUID) async {
        guard let meeting = meetings.first(where: { $0.id == id }), !summarizing.contains(id) else { return }
        let text = meeting.transcript.plainText
        guard !text.isEmpty else { return }
        summarizing.insert(id)
        defer { summarizing.remove(id) }

        var summary: MeetingSummary
        do {
            if let cloud = try await Tasks.summarize(transcript: text) {
                summary = MeetingSummary(text: cloud.text, actionItems: cloud.actionItems,
                                         speakers: cloud.speakers.map { "\($0.name): \($0.points)" })
            } else {
                summary = await Self.onDevice(text)
            }
        } catch {
            self.error = "Cloud summary failed (\(error.localizedDescription)). Summarized on this Mac instead."
            summary = await Self.onDevice(text)
        }
        summaries[id] = summary
        try? JSONEncoder().encode(summary).write(to: summaryURL(meeting), options: .atomic)
    }

    func delete(_ id: UUID) {
        guard let meeting = meetings.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: meeting.recording.folder)
        meetings.removeAll { $0.id == id }
        summaries[id] = nil
        if selection == id { selection = nil }
    }

    private static func onDevice(_ text: String) async -> MeetingSummary {
        let s = await Intelligence.summarize(text) ?? Summarizer.extractive(text)
        return MeetingSummary(text: s.text, actionItems: s.actionItems, speakers: [])
    }

    private func summaryURL(_ meeting: Meeting) -> URL {
        meeting.recording.folder.appendingPathComponent("summary.json")
    }
}

struct MeetingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showProfiles = false

    var body: some View {
        @Bindable var meetings = model.meetings
        NavigationStack {
            List {
                Section {
                    MeetingRecorderControl(recorder: meetings.recorder) { recording in
                        Task { await meetings.process(recording) }
                    }
                    .padding(.vertical, 4)
                }
                Section("Recent") {
                    if meetings.meetings.isEmpty && meetings.processing.isEmpty {
                        Text("Recorded calls appear here, with who said what.")
                            .foregroundStyle(.secondary)
                    }
                    if !meetings.processing.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Separating speakers and transcribing on this Mac…").foregroundStyle(.secondary)
                        }
                    }
                    ForEach(meetings.meetings) { meeting in
                        Button { meetings.selection = meeting.id } label: {
                            MeetingRow(meeting: meeting).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) { meetings.delete(meeting.id) }
                        }
                    }
                }
            }
            .navigationDestination(item: $meetings.selection) { id in
                MeetingPage(id: id).environment(model)
            }
            .toolbar {
                ToolbarItem {
                    Button { showProfiles = true } label: { Label("Voice Profiles", systemImage: "person.crop.circle.badge.checkmark") }
                        .help("People Murmur recognizes by voice")
                }
            }
            .sheet(isPresented: $showProfiles) {
                VStack(alignment: .trailing, spacing: 0) {
                    VoiceProfilesView(store: meetings.profiles)
                    Button("Done") { showProfiles = false }.keyboardShortcut(.defaultAction).padding(12)
                }
                .frame(width: 440, height: 420)
            }
            .alert("Meetings", isPresented: Binding(get: { meetings.error != nil }, set: { if !$0 { meetings.error = nil } })) {
                Button("OK") { meetings.error = nil }
            } message: {
                Text(meetings.error ?? "")
            }
        }
        .navigationTitle("Meetings")
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.wave.2").foregroundStyle(Color.accentColor).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.recording.title).lineLimit(1)
                Text("\(meeting.recording.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(Transcript.clock(meeting.recording.duration)) · \(meeting.speakers.count + 1) speaker\(meeting.speakers.isEmpty ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MeetingPage: View {
    @Environment(AppModel.self) private var model
    let id: UUID

    var body: some View {
        let meetings = model.meetings
        if let binding = meetings.binding(for: id) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Spacer()
                        Button { copy(binding.wrappedValue.transcript.markdown(title: binding.wrappedValue.recording.title)) } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .help("Copy transcript")
                        Button { export(binding.wrappedValue) } label: { Image(systemName: "square.and.arrow.up") }
                            .help("Export Markdown")
                    }
                    Card(title: "Summary", symbol: "sparkles") {
                        if meetings.summarizing.contains(id) {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Summarizing…").foregroundStyle(.secondary)
                            }
                        } else if let summary = meetings.summaries[id] {
                            Text(summary.text).textSelection(.enabled)
                            if !summary.speakers.isEmpty {
                                Text("By speaker").font(.subheadline.weight(.semibold)).padding(.top, 4)
                                ForEach(summary.speakers, id: \.self) { Text("• " + $0).textSelection(.enabled) }
                            }
                            if !summary.actionItems.isEmpty {
                                Text("Action items").font(.subheadline.weight(.semibold)).padding(.top, 4)
                                ForEach(summary.actionItems, id: \.self) { Label($0, systemImage: "circle").textSelection(.enabled) }
                            }
                            Button("Summarize Again") { Task { await meetings.summarize(id) } }
                                .buttonStyle(.link).font(.caption)
                        } else {
                            Button("Summarize") { Task { await meetings.summarize(id) } }
                        }
                    }
                    // Click a speaker's name to rename them; the voice profile remembers them next time.
                    MeetingDetailView(meeting: binding, profiles: meetings.profiles)
                }
                .padding(18)
            }
            .navigationTitle(binding.wrappedValue.recording.title)
        } else {
            ContentUnavailableView("Meeting Deleted", systemImage: "trash")
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func export(_ meeting: Meeting) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = meeting.recording.title + ".md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var text = meeting.transcript.markdown(title: meeting.recording.title)
        if let summary = model.meetings.summaries[meeting.id] {
            text = "## Summary\n\n\(summary.text)\n\n" + summary.actionItems.map { "- [ ] \($0)" }.joined(separator: "\n") + "\n\n" + text
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
