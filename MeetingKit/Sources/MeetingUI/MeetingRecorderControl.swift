import AppKit
import MeetingKit
import SwiftUI

/// Compact recorder: pick the call's app, start/stop, see both tracks' levels.
///
/// Other people on the call see no indicator from this app, so the user's own notice is
/// the only one they get. Hence: a one-time intro the first time Meetings opens, and a
/// confirmation before every recording, whose time is saved with the recording.
public struct MeetingRecorderControl: View {
    @ObservedObject var recorder: MeetingRecorder
    var onFinish: (MeetingRecording) -> Void

    /// Pasted into the call's chat by "Copy to Chat".
    public static let announcement = "Heads up: I'm recording and transcribing this call on my Mac."
    /// Bump when the intro's wording changes, so everyone sees it again.
    static let introVersion = 1

    @AppStorage("MeetingKit.consentIntroVersion") private var acceptedIntro = 0
    @AppStorage("MeetingKit.consentIntroAcceptedAt") private var acceptedIntroAt = 0.0
    @State private var apps: [AudioApp] = []
    /// Bundle ID of the chosen app, `Self.allAudio`, or empty until the user picks one.
    /// Never falls back to all system audio on its own.
    @State private var selection = ""
    static let allAudio = "*all"
    @State private var error: String?
    @State private var showIntro = false
    @State private var confirming = false
    @State private var everyoneAgreed = false
    @State private var confirmDiscard = false
    @State private var copied = false
    @State private var announcementCopiedAt: Date?

    public init(recorder: MeetingRecorder, onFinish: @escaping (MeetingRecording) -> Void) {
        self.recorder = recorder
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Picker("Record", selection: $selection) {
                    if selection.isEmpty { Text("Choose the call's app").tag("") }
                    ForEach(apps) { app in
                        Text(app.isPlayingAudio ? "\(app.name) ♪" : app.name).tag(app.bundleID)
                    }
                    Divider()
                    Text("All system audio (includes media and other calls)").tag(Self.allAudio)
                }
                .labelsHidden()
                .disabled(recorder.isRecording)
                Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .disabled(recorder.isRecording)
                    .help("Refresh the list of apps")
            }

            HStack(spacing: 8) {
                Button(action: recordTapped) {
                    Label(recorder.isRecording ? "Stop" : "Record",
                          systemImage: recorder.isRecording ? "stop.fill" : "record.circle")
                }
                .controlSize(.large)
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!recorder.isRecording && selection.isEmpty)
                .popover(isPresented: $confirming, arrowEdge: .bottom) { confirmation }
                if recorder.isRecording {
                    Button("Stop & Delete", role: .destructive) { confirmDiscard = true }
                        .help("Someone objected: stop and delete this recording")
                }
            }
            if let startedAt = recorder.startedAt {
                HStack(spacing: 6) {
                    RecordingIndicator()
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        Text("Recording · \(MeetingTranscript.timestamp(context.date.timeIntervalSince(startedAt)))")
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    if let method = recorder.captureMethod {
                        Text(method).font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    announceButton
                }
            }

            Meter(label: "You", value: Double(recorder.micLevel))
            Meter(label: "Call", value: Double(recorder.systemLevel))

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            } else {
                ForEach([recorder.micError, recorder.callAudioError].compactMap { $0 }, id: \.self) {
                    Text($0).font(.caption).foregroundStyle(.orange)
                }
            }
            Label("People on the call see no indicator from this app. Tell them before you start, and stop if anyone objects.",
                  systemImage: "person.wave.2")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            refresh()
            if acceptedIntro < Self.introVersion { showIntro = true }
        }
        .sheet(isPresented: $showIntro) {
            ConsentIntro {
                acceptedIntro = Self.introVersion
                acceptedIntroAt = Date().timeIntervalSince1970
            }
        }
        .confirmationDialog("Stop and delete this recording?", isPresented: $confirmDiscard) {
            Button("Stop & Delete", role: .destructive) { Task { await recorder.discard() } }
        } message: {
            Text("Both audio tracks are removed from this Mac.")
        }
    }

    private var announceButton: some View {
        Button(copied ? "Copied" : "Copy to Chat") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.announcement, forType: .string)
            copied = true
            if recorder.isRecording { recorder.announcementCopied() } else { announcementCopiedAt = Date() }
            Task { try? await Task.sleep(for: .seconds(2)); copied = false }
        }
        .controlSize(.small)
        .help("Copies “\(Self.announcement)” to paste into the call's chat")
    }

    /// Shown before every recording; Start stays disabled until the box is ticked.
    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tell everyone you're recording").font(.headline)
            Text("Say it, or paste this into the call's chat:").font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .top) {
                Text("“\(Self.announcement)”").font(.callout).textSelection(.enabled)
                Spacer()
                announceButton
            }
            Toggle("I've told everyone on this call it's being recorded, and they agreed.", isOn: $everyoneAgreed)
            HStack {
                Spacer()
                Button("Cancel") { confirming = false }
                Button("Start Recording") {
                    confirming = false
                    start(consentConfirmedAt: Date())
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!everyoneAgreed)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private func refresh() {
        apps = MeetingRecorder.availableApps()
        if selection != Self.allAudio, !apps.contains(where: { $0.bundleID == selection }) { selection = "" }
        if selection.isEmpty, let playing = apps.first(where: \.isPlayingAudio) { selection = playing.bundleID }
    }

    private func recordTapped() {
        error = nil
        if recorder.isRecording {
            Task { if let recording = await recorder.stop() { onFinish(recording) } }
        } else if acceptedIntro < Self.introVersion {
            showIntro = true
        } else {
            everyoneAgreed = false // asked every time, never remembered
            announcementCopiedAt = nil
            confirming = true
        }
    }

    private func start(consentConfirmedAt: Date) {
        Task {
            // Process lists change as calls start; resolve the app fresh at the last moment.
            let chosen = selection
            refresh()
            let source: AudioSource
            if chosen == Self.allAudio {
                source = .allSystemAudio
            } else if let app = apps.first(where: { $0.bundleID == chosen }) {
                source = .app(app)
            } else {
                error = "That app isn't running anymore. Choose the call's app again."
                return
            }
            do {
                try await recorder.start(source, consentConfirmedAt: consentConfirmedAt, announcementCopiedAt: announcementCopiedAt)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

/// One-time sheet the first time Meetings opens (and again when its wording changes).
private struct ConsentIntro: View {
    let accept: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording other people requires their consent").font(.title3.bold())
            Text("Meetings records your microphone and the call's audio on this Mac. People on the call won't see any recording indicator from their meeting app.")
            Text("In Massachusetts, California and many other places, recording a conversation without the consent of everyone in it is a crime. Participants may be in different states or countries.")
            Toggle("I'll tell everyone I'm recording before I start, and I'll stop if anyone objects.", isOn: $agreed)
            HStack {
                Spacer()
                Button("Not Now") { dismiss() }
                Button("Continue") {
                    accept()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!agreed)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
