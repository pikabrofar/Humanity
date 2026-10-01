import AppKit
import AVFoundation
import VozKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    var body: some View {
        @Bindable var model = model
        let results = model.recordings.filter { $0.matches(query) }
        HSplitView {
            List(results, selection: $model.selection) { recording in
                RecordingRow(recording: recording).tag(recording.id)
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 380)
            .overlay {
                if model.recordings.isEmpty {
                    ContentUnavailableView("No Recordings", systemImage: "waveform",
                                           description: Text("Dictations and notes appear here."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }

            Group {
                if let id = model.selection, let recording = model.recordings.first(where: { $0.id == id }) {
                    RecordingDetail(recording: recording).id(id)
                } else {
                    ContentUnavailableView("Select a Recording", systemImage: "text.quote")
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $query, prompt: "Search transcripts")
        .navigationTitle("Library")
    }
}

struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: recording.kind == .note ? "record.circle" : "text.cursor")
                .foregroundStyle(recording.kind == .note ? Color.red : Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = [recording.createdAt.formatted(.relative(presentation: .named)), Transcript.clock(recording.duration)]
        if let app = recording.targetApp { parts.append(app) }
        return parts.joined(separator: " · ")
    }
}

private struct RecordingDetail: View {
    @Environment(AppModel.self) private var model
    let recording: Recording
    @State private var showRaw = false
    @State private var player = AudioPlayback()
    @State private var confirmDelete = false

    var body: some View {
        let hasAudio = model.store.hasAudio(recording.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recording.title).font(.title2.weight(.semibold)).textSelection(.enabled)
                    HStack(spacing: 8) {
                        StatusChip(text: recording.kind == .note ? "Note" : "Dictation",
                                   symbol: recording.kind == .note ? "record.circle" : "text.cursor")
                        StatusChip(text: Transcript.clock(recording.duration), symbol: "clock")
                        if let app = recording.targetApp { StatusChip(text: app, symbol: "app") }
                        Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack {
                    if hasAudio {
                        Button { player.toggle(model.store.audioURL(for: recording.id)) } label: {
                            Label(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                        }
                        if player.progress > 0 { ProgressView(value: player.progress).frame(width: 80) }
                    }
                    Button { copy(recording.text) } label: { Label("Copy", systemImage: "doc.on.doc") }
                    Button { export() } label: { Label("Export Markdown…", systemImage: "square.and.arrow.up") }
                    Spacer()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                }

                Card(title: "Summary", symbol: "sparkles") {
                    if model.summarizing.contains(recording.id) {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Summarizing on this Mac…").foregroundStyle(.secondary)
                        }
                    } else if let summary = recording.summary {
                        Text(summary).textSelection(.enabled)
                        if !recording.actionItems.isEmpty {
                            Text("Action items").font(.subheadline.weight(.semibold)).padding(.top, 4)
                            ForEach(recording.actionItems, id: \.self) { item in
                                Label(item, systemImage: "circle").textSelection(.enabled)
                            }
                        }
                        Button("Summarize Again") { Task { await model.summarize(recording.id) } }
                            .buttonStyle(.link).font(.caption)
                    } else {
                        Text(Intelligence.isAvailable && model.useIntelligence
                             ? "Get a short summary and action items from Apple's on-device model."
                             : "Get the key sentences and action items. With Apple Intelligence on, summaries are written by its on-device model.")
                            .foregroundStyle(.secondary)
                        Button("Summarize") { Task { await model.summarize(recording.id) } }
                    }
                }

                Card(title: "Transcript", symbol: "text.alignleft") {
                    if recording.cleaned != nil, recording.cleaned != recording.transcript {
                        Picker("Version", selection: $showRaw) {
                            Text("Cleaned").tag(false)
                            Text("As spoken").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    Text(showRaw ? recording.transcript : recording.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
        .onDisappear { player.stop() }
        .confirmationDialog("Delete this recording?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { model.delete(recording.id) }
        } message: {
            Text("The audio and transcript are removed from this Mac.")
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = MarkdownExporter.fileName(for: recording)
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? MarkdownExporter.markdown(for: recording).write(to: url, atomically: true, encoding: .utf8)
    }
}

@MainActor @Observable
final class AudioPlayback {
    private(set) var isPlaying = false
    private(set) var progress = 0.0
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?

    func toggle(_ url: URL) {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        if player == nil { player = try? AVAudioPlayer(contentsOf: url) }
        guard let player, player.play() else { return }
        isPlaying = true
        // AVAudioPlayer's delegate would need an NSObject; polling is simpler for a progress bar.
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        player?.stop()
        timer?.invalidate()
        isPlaying = false
    }

    private func tick() {
        guard let player else { return }
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
        if !player.isPlaying {
            timer?.invalidate()
            isPlaying = false
            if progress < 0.01 || progress > 0.99 { progress = 0 }
        }
    }
}
