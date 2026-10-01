import AppKit
import Carbon.HIToolbox
import AIKit
import MeetingKit
import MurmurKit
import Observation
import OSLog
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home, meetings, library, setup
    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Dictate"
        case .meetings: "Meetings"
        case .library: "Library"
        case .setup: "Quick Setup"
        }
    }

    var symbol: String {
        switch self {
        case .home: "mic"
        case .meetings: "person.2.wave.2"
        case .library: "tray.full"
        case .setup: "checklist"
        }
    }
}

private let latency = Logger(subsystem: "Murmur", category: "latency")

@MainActor @Observable
final class AppModel {
    /// Created on first use: loading the diarization models costs memory.
    @ObservationIgnored private var loadedMeetings: MeetingsModel?
    var meetings: MeetingsModel {
        if let loadedMeetings { return loadedMeetings }
        let meetings = MeetingsModel()
        loadedMeetings = meetings
        return meetings
    }
    enum Phase: Equatable {
        case idle
        /// Choosing an engine; the mic isn't open yet.
        case preparing
        case listening
        /// Mic closed; finishing the transcript, cleaning up and inserting.
        case finishing
    }

    var section: SidebarSection? = Defaults.bool(.completedSetup, default: false) ? .home : .setup
    var selection: Recording.ID?
    private(set) var phase = Phase.idle
    private(set) var mode = Recording.Kind.dictation
    private(set) var level: Float = 0
    private(set) var partial = ""
    /// A short message for the HUD, e.g. "Copied. Press ⌘V to paste."
    private(set) var notice: String?
    private(set) var recordings: [Recording] = []
    private(set) var summarizing: Set<UUID> = []
    private(set) var transcribing: Set<UUID> = []
    private(set) var microphone = Permissions.microphone
    private(set) var speech = Permissions.speech
    private(set) var canPaste = Permissions.canPaste

    var cleanup = Defaults.bool(.cleanup, default: true) {
        didSet { Defaults.set(cleanup, .cleanup) }
    }
    var useIntelligence = Defaults.bool(.useIntelligence, default: true) {
        didSet { Defaults.set(useIntelligence, .useIntelligence) }
    }
    var keepHistory = Defaults.bool(.keepHistory, default: true) {
        didSet { Defaults.set(keepHistory, .keepHistory) }
    }
    var restoreClipboard = Defaults.bool(.restoreClipboard, default: true) {
        didSet { Defaults.set(restoreClipboard, .restoreClipboard) }
    }
    /// Names and jargon, comma-separated: hints for the recognizer and exact spellings.
    var vocabulary = Defaults.string(.vocabulary) {
        didSet { Defaults.set(vocabulary, .vocabulary) }
    }
    /// False until the speech engine is running; the first start may download Apple's model.
    private(set) var engineReady = false

    let store = RecordingStore.standard

    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private var transcriber: LiveTranscriber?
    @ObservationIgnored private var transcriberReady: Task<Void, Error>?
    /// `secure`: a password field (or other secure input) was focused when it started.
    @ObservationIgnored private var session: (id: UUID, startedAt: Date, targetApp: String?, secure: Bool)?
    @ObservationIgnored private var stopRequested = false
    @ObservationIgnored private var trigger = TalkTrigger()
    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var cancelKey: HotKey?
    @ObservationIgnored private var hud: HUDPanel?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private var permissionTimer: Timer?

    init() {
        recordings = store.loadAll()
        // ⌃⌥⌘D from any app: tap to toggle, hold to talk.
        hotKey = HotKey(keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey | cmdKey,
                        onPress: { [weak self] in MainActor.assumeIsolated { self?.hotKeyPressed() } },
                        onRelease: { [weak self] in MainActor.assumeIsolated { self?.hotKeyReleased() } })
        // There's no callback when a permission is granted in System Settings, so poll.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
    }

    var isActive: Bool { phase != .idle }
    var hotKeyMissing: Bool { hotKey == nil }

    func refreshPermissions() {
        microphone = Permissions.microphone
        speech = Permissions.speech
        canPaste = Permissions.canPaste
    }

    func completeSetup() {
        Defaults.set(true, .completedSetup)
        section = .home
    }

    // MARK: Recording

    func toggle(_ kind: Recording.Kind) {
        isActive ? stop() : start(kind)
    }

    func start(_ kind: Recording.Kind) {
        guard phase == .idle else { return }
        guard microphone == .granted else {
            Task {
                // Asks only the first time; afterwards it returns the stored answer.
                let granted = await Permissions.requestMicrophone()
                refreshPermissions()
                if granted { start(kind) } else { flash("Murmur needs microphone access.", showSetup: true) }
            }
            return
        }
        let id = UUID()
        mode = kind
        partial = ""
        notice = nil
        stopRequested = false
        engineReady = false
        phase = .preparing
        let secure = kind == .dictation && IsSecureEventInputEnabled()
        session = (id, Date(), NSWorkspace.shared.frontmostApplication?.localizedName, secure)
        updateHUD()
        // Esc cancels, but only while recording: a global Esc would break every other app.
        cancelKey = HotKey(keyCode: kVK_Escape, modifiers: 0,
                           onPress: { [weak self] in MainActor.assumeIsolated { self?.cancel() } })
        if kind == .dictation, cleanup, useIntelligence { Intelligence.prewarm() }

        Task {
            let transcriber = await Transcribers.make(vocabulary: TextCleanup.terms(from: vocabulary))
            // Every step below re-checks the session: Esc or an error may have ended it meanwhile.
            guard session?.id == id else { return }
            transcriber.onPartial = { [weak self] in self?.partial = $0 }
            self.transcriber = transcriber
            do {
                let saveAudio = (keepHistory && !secure) || kind == .note
                if saveAudio { try store.prepare() }
                try recorder.start(writingTo: saveAudio ? store.audioURL(for: id) : nil,
                                   onBuffer: { transcriber.append($0) },
                                   onLevel: { [weak self] level in Task { @MainActor in self?.level = level } },
                                   onLost: { [weak self] in self?.microphoneLost() })
            } catch {
                fail(error)
                return
            }
            phase = .listening
            NSSound(named: "Tink")?.play()
            let ready = Task { try await transcriber.start() }
            transcriberReady = ready
            if stopRequested { stop() }
            do {
                try await ready.value
                if session?.id == id { engineReady = true }
            } catch {
                // Also after stop(), which leaves reporting the error to this.
                if session?.id == id { fail(error) }
            }
        }
    }

    func stop() {
        guard phase == .listening, let id = session?.id else {
            if phase == .preparing { stopRequested = true }
            return
        }
        phase = .finishing
        cancelKey = nil
        let released = ContinuousClock.now
        let (duration, audioError) = recorder.stop()
        level = 0
        NSSound(named: "Pop")?.play()
        let transcriber = transcriber, ready = transcriberReady
        // Never leave the HUD up: if the engine stalls, keep what was heard so far.
        // A first start may still be downloading Apple's model, so allow longer then.
        let limit = engineReady ? 3 + duration / 20 : 30
        Task {
            let raw = await firstResult(within: .seconds(limit)) { @MainActor () -> String? in
                guard let transcriber, (try? await ready?.value) != nil else { return nil }
                return await transcriber.finish()
            } orElse: { @MainActor () -> String? in
                transcriber?.cancel()
                return self.partial
            }
            guard session?.id == id, let raw else { return }
            await complete(raw: raw, duration: duration, released: released, audioError: audioError)
        }
    }

    func cancel() {
        guard phase == .listening || phase == .preparing else { return }
        recorder.stop()
        transcriber?.cancel()
        discardSession()
        flash("Cancelled")
    }

    /// The input device changed or disconnected mid-recording: keep what was said.
    private func microphoneLost() {
        guard phase == .listening else { return }
        stop()
        flash("Microphone changed. Kept what you said so far.", duration: .seconds(3))
    }

    private func complete(raw heard: String, duration: TimeInterval, released: ContinuousClock.Instant,
                          audioError: Error?) async {
        guard let session else { return }
        let terms = TextCleanup.terms(from: vocabulary)
        let raw = TextCleanup.respell(heard, terms: terms)
        guard !raw.isEmpty else {
            flash(discardSession(keepNote: true) ? "No words found. The audio is in the Library to transcribe again."
                                                 : "Didn't catch that. Try again a little closer to the mic.")
            return
        }
        // Dictating into a password field: the text goes only there. No cleanup (cloud or
        // on-device), no history, no audio left on disk.
        let secure = mode == .dictation && (session.secure || IsSecureEventInputEnabled())
        var cleaned: String?
        if cleanup, !secure {
            // A cloud model the user connected (AIKit), else Apple Intelligence, else rules.
            // The rewrite check guards against a model answering the text instead of editing it.
            // Dictation waits at most 2 s for a model so the text still lands promptly.
            let useIntelligence = useIntelligence
            let rewrite = await firstResult(within: .seconds(mode == .dictation ? 2 : 60)) { @MainActor () -> String? in
                if let cloud = (try? await Tasks.cleanup(raw)).flatMap({ TextCleanup.acceptRewrite($0, of: raw) }) { return cloud }
                return useIntelligence ? await Intelligence.polish(raw) : nil
            } orElse: { nil }
            cleaned = TextCleanup.respell(rewrite ?? TextCleanup.basic(raw), terms: terms)
        }
        let recording = Recording(id: session.id, createdAt: session.startedAt, duration: duration, kind: mode,
                                  transcript: raw, cleaned: cleaned,
                                  targetApp: mode == .dictation ? session.targetApp : nil)
        var message = audioError.map { "The audio wasn't saved: \($0.localizedDescription)" }
        if mode == .dictation {
            if await TextInserter.insert(recording.text, restoreClipboard: restoreClipboard) {
                // Console.app, subsystem "Murmur": the number to keep under 500 ms.
                let ms = Int(released.duration(to: .now) / .milliseconds(1))
                latency.info("Key release to text inserted: \(ms) ms")
            } else {
                message = "Copied. Press ⌘V to paste, or allow Accessibility in Quick Setup."
            }
        }
        self.session = nil
        transcriber = nil
        transcriberReady = nil
        if secure {
            store.delete(recording.id)
        } else if mode == .note || keepHistory {
            try? store.save(recording)
            recordings.insert(recording, at: 0)
        }
        phase = .idle
        if mode == .note {
            selection = recording.id
            flash(message ?? "Saved to Library")
            await summarize(recording.id)
        } else if let message {
            flash(message)
        } else {
            updateHUD()
        }
    }

    /// Ends the session and deletes its audio, except `keepNote`: a note whose transcript
    /// failed or came back empty keeps its audio, listed in the Library for a retry.
    /// - Returns: true when a note was kept.
    @discardableResult
    private func discardSession(keepNote: Bool = false) -> Bool {
        var kept = false
        if let session {
            if keepNote, mode == .note, store.hasAudio(session.id) {
                let recording = Recording(id: session.id, createdAt: session.startedAt,
                                          duration: Date().timeIntervalSince(session.startedAt), kind: .note, transcript: "")
                try? store.save(recording) // if this fails the audio still stays on disk
                recordings.insert(recording, at: 0)
                kept = true
            } else {
                store.delete(session.id)
            }
        }
        session = nil
        transcriber = nil
        transcriberReady = nil
        cancelKey = nil
        level = 0
        phase = .idle
        updateHUD()
        return kept
    }

    private func fail(_ error: Error) {
        recorder.stop()
        transcriber?.cancel()
        let kept = discardSession(keepNote: true)
        flash(error.localizedDescription + (kept ? " The audio is in the Library to transcribe again." : ""), duration: .seconds(4))
    }

    /// Before the app quits: finalize a meeting's audio (it's listed to process on the next
    /// launch) and keep a note's audio for a transcription retry. A dictation is dropped.
    func prepareToQuit() async {
        await loadedMeetings?.recorder.stop()
        guard phase != .idle else { return }
        recorder.stop()
        transcriber?.cancel()
        discardSession(keepNote: true)
    }

    // MARK: Hotkey

    private func hotKeyPressed() {
        switch trigger.press(at: ProcessInfo.processInfo.systemUptime, isRecording: isActive) {
        case .start: start(.dictation)
        case .stop: stop()
        case .none: break
        }
    }

    private func hotKeyReleased() {
        if trigger.release(at: ProcessInfo.processInfo.systemUptime, isRecording: isActive) == .stop { stop() }
    }

    // MARK: Library

    func summarize(_ id: UUID) async {
        guard let text = recordings.first(where: { $0.id == id })?.text, !summarizing.contains(id) else { return }
        summarizing.insert(id)
        var summary: Summary
        do {
            if let cloud = try await Tasks.summarize(transcript: text) {
                summary = Summary(text: cloud.text, actionItems: cloud.actionItems)
            } else {
                summary = await (useIntelligence ? Intelligence.summarize(text) : nil) ?? Summarizer.extractive(text)
            }
        } catch {
            // The chosen provider failed (no key, offline, rate limit): stay useful on-device.
            flash("Cloud summary failed: \(error.localizedDescription). Summarized on this Mac instead.")
            summary = await (useIntelligence ? Intelligence.summarize(text) : nil) ?? Summarizer.extractive(text)
        }
        summarizing.remove(id)
        update(id) {
            $0.summary = summary.text
            $0.actionItems = summary.actionItems
        }
    }

    /// For a note saved without a transcript: transcribe its audio file on this Mac.
    func retryTranscription(_ id: UUID) async {
        guard !transcribing.contains(id) else { return }
        transcribing.insert(id)
        defer { transcribing.remove(id) }
        do {
            let words = try await SpeechFileTranscriber().transcribe(store.audioURL(for: id))
            let raw = TextCleanup.respell(words.map(\.text).reduce("", Transcript.join), terms: TextCleanup.terms(from: vocabulary))
            guard !raw.isEmpty else { return flash("Still no words found in this recording.") }
            update(id) {
                $0.transcript = raw
                $0.cleaned = cleanup ? TextCleanup.basic(raw) : nil
            }
            await summarize(id)
        } catch {
            flash("Couldn't transcribe: \(error.localizedDescription)", duration: .seconds(4))
        }
    }

    func delete(_ id: UUID) {
        store.delete(id)
        recordings.removeAll { $0.id == id }
        if selection == id { selection = nil }
    }

    func deleteAll() {
        recordings.forEach { store.delete($0.id) }
        recordings = []
        selection = nil
    }

    private func update(_ id: UUID, _ change: (inout Recording) -> Void) {
        guard let i = recordings.firstIndex(where: { $0.id == id }) else { return }
        change(&recordings[i])
        try? store.save(recordings[i])
    }

    // MARK: HUD

    private func flash(_ message: String, duration: Duration = .seconds(2), showSetup: Bool = false) {
        notice = message
        if showSetup { section = .setup }
        updateHUD()
        noticeTask?.cancel()
        noticeTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            notice = nil
            updateHUD()
        }
    }

    private func updateHUD() {
        if isActive || notice != nil {
            if hud == nil { hud = HUDPanel(content: HUDView().environment(self)) }
            hud?.present()
        } else {
            hud?.orderOut(nil)
        }
    }
}
