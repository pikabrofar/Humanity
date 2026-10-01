import MeetingKit
import SwiftUI

/// Compact recorder: pick the call's app, start/stop, see both tracks' levels.
public struct MeetingRecorderControl: View {
    @ObservedObject var recorder: MeetingRecorder
    var onFinish: (MeetingRecording) -> Void

    @State private var apps: [AudioApp] = []
    /// Bundle ID of the chosen app; empty means all system audio.
    @State private var selection = ""
    @State private var error: String?

    public init(recorder: MeetingRecorder, onFinish: @escaping (MeetingRecording) -> Void) {
        self.recorder = recorder
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Picker("Record", selection: $selection) {
                    ForEach(apps) { app in
                        Text(app.isPlayingAudio ? "\(app.name) ♪" : app.name).tag(app.bundleID)
                    }
                    Divider()
                    Text("All system audio").tag("")
                }
                .labelsHidden()
                .disabled(recorder.isRecording)
                Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .disabled(recorder.isRecording)
                    .help("Refresh the list of apps")
            }

            HStack(spacing: 8) {
                Button(action: toggle) {
                    Label(recorder.isRecording ? "Stop" : "Record",
                          systemImage: recorder.isRecording ? "stop.fill" : "record.circle")
                }
                .controlSize(.large)
                .keyboardShortcut("r", modifiers: [.command, .shift])
                if let startedAt = recorder.startedAt {
                    RecordingIndicator()
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        Text(MeetingTranscript.timestamp(context.date.timeIntervalSince(startedAt)))
                            .font(.callout.monospacedDigit())
                    }
                    if let method = recorder.captureMethod {
                        Text(method).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }

            Meter(label: "You", value: Double(recorder.micLevel))
            Meter(label: "Call", value: Double(recorder.systemLevel))

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            // Recording people without telling them is illegal in many places
            // (all-party-consent laws) and erodes trust everywhere else.
            Label("Tell everyone on the call that you're recording before you start.",
                  systemImage: "person.wave.2")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 300)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        apps = MeetingRecorder.availableApps()
        if !selection.isEmpty, !apps.contains(where: { $0.bundleID == selection }) { selection = "" }
        if selection.isEmpty, let playing = apps.first(where: \.isPlayingAudio) { selection = playing.bundleID }
    }

    private func toggle() {
        error = nil
        Task {
            if recorder.isRecording {
                if let recording = await recorder.stop() { onFinish(recording) }
                return
            }
            // Process lists change as calls start; resolve the app fresh at the last moment.
            refresh()
            let source = apps.first { $0.bundleID == selection }.map(AudioSource.app) ?? .allSystemAudio
            do {
                try await recorder.start(source)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
