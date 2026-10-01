import AppKit
import Carbon.HIToolbox
import AIKit
import MurmurKit
import Observation
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home, library, setup
    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Dictate"
        case .library: "Library"
        case .setup: "Quick Setup"
        }
    }

    var symbol: String {
        switch self {
        case .home: "mic"
        case .library: "tray.full"
        case .setup: "checklist"
        }
    }
}

@MainActor @Observable
final class AppModel {
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

    let store = RecordingStore.standard

    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private var transcriber: LiveTranscriber?
    @ObservationIgnored private var transcriberReady: Task<Void, Error>?
    @ObservationIgnored private var session: (id: UUID, startedAt: Date, targetApp: String?)?
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
        phase = .preparing
        session = (id, Date(), NSWorkspace.shared.frontmostApplication?.localizedName)
        updateHUD()

        Task {
            let transcriber = await Transcribers.make()
            transcriber.onPartial = { [weak self] in self?.partial = $0 }
            self.transcriber = transcriber
            do {
                let saveAudio = keepHistory || kind == .note
                if saveAudio { try store.prepare() }
                try recorder.start(writingTo: saveAudio ? store.audioURL(for: id) : nil,
                                   onBuffer: { transcriber.append($0) },
                                   onLevel: { [weak self] level in Task { @MainActor in self?.level = level } })
            } catch {
                fail(error)
                return
            }
            phase = .listening
            NSSound(named: "Tink")?.play()
            // Esc cancels, but only while recording: a global Esc would break every other app.
            cancelKey = HotKey(keyCode: kVK_Escape, modifiers: 0,
                               onPress: { [weak self] in MainActor.assumeIsolated { self?.cancel() } })
            let ready = Task { try await transcriber.start() }
            transcriberReady = ready
            if stopRequested { stop() }
            do { try await ready.value } catch { if phase == .listening { fail(error) } }
        }
    }

    func stop() {
        guard phase == .listening else {
            if phase == .preparing { stopRequested = true }
            return
        }
        phase = .finishing
        cancelKey = nil
        let duration = recorder.stop()
        level = 0
        NSSound(named: "Pop")?.play()
        Task {
            var raw = ""
            if let transcriber, (try? await transcriberReady?.value) != nil {
                raw = await transcriber.finish()
            }
            await complete(raw: raw, duration: duration)
        }
    }

    func cancel() {
        guard phase == .listening || phase == .preparing else { return }
        recorder.stop()
        transcriber?.cancel()
        discardSession()
        flash("Cancelled")
    }

    private func complete(raw: String, duration: TimeInterval) async {
        guard let session else { return }
        guard !raw.isEmpty else {
            discardSession()
            flash("Didn't catch that. Try again a little closer to the mic.")
            return
        }
        var cleaned: String?
        if cleanup {
            // A cloud model the user connected (AIKit), else Apple Intelligence, else rules.
            // The rewrite check guards against a model answering the text instead of editing it.
            let cloud = (try? await Tasks.cleanup(raw)).flatMap { TextCleanup.acceptRewrite($0, of: raw) }
            if let cloud {
                cleaned = cloud
            } else {
                cleaned = await (useIntelligence ? Intelligence.polish(raw) : nil) ?? TextCleanup.basic(raw)
            }
        }
        let recording = Recording(id: session.id, createdAt: session.startedAt, duration: duration, kind: mode,
                                  transcript: raw, cleaned: cleaned,
                                  targetApp: mode == .dictation ? session.targetApp : nil)
        var message: String?
        if mode == .dictation, !(await TextInserter.insert(recording.text, restoreClipboard: restoreClipboard)) {
            message = "Copied. Press ⌘V to paste, or allow Accessibility in Quick Setup."
        }
        self.session = nil
        transcriber = nil
        if mode == .note || keepHistory {
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

    private func discardSession() {
        if let session { store.delete(session.id) }
        session = nil
        transcriber = nil
        cancelKey = nil
        level = 0
        phase = .idle
        updateHUD()
    }

    private func fail(_ error: Error) {
        recorder.stop()
        transcriber?.cancel()
        discardSession()
        flash(error.localizedDescription, duration: .seconds(4))
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
