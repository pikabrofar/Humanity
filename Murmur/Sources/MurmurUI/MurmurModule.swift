import AppKit
import MurmurKit
import SwiftUI

/// Public entry point for hosting Murmur: the standalone app and the Humanity
/// suite both build their windows from this.
@MainActor
public final class MurmurModule {
    let model = AppModel()

    public init() {}

    /// Sections for a host's sidebar, as (id, title, SF Symbol).
    public static let sections: [(id: String, title: String, symbol: String)] =
        SidebarSection.allCases.map { ($0.rawValue, $0.title, $0.symbol) }

    public var selectedSection: String? {
        get { model.section?.rawValue }
        set { model.section = newValue.flatMap(SidebarSection.init(rawValue:)) }
    }

    /// True while recording or transcribing.
    public var isListening: Bool { model.isActive }
    public var hasMicrophone: Bool { model.microphone == .granted }
    public var canPaste: Bool { model.canPaste }
    /// True while a meeting is being recorded; show it in the menu bar (observable).
    public var isRecordingMeeting: Bool { model.isRecordingMeeting }

    public func toggleDictation() { model.toggle(.dictation) }
    public func toggleNote() { model.toggle(.note) }

    /// Call from `applicationShouldTerminate` (reply `.terminateLater`, then
    /// `reply(toApplicationShouldTerminate: true)` when this returns): stops a meeting
    /// or note in progress and finalizes its audio, which is otherwise unreadable.
    public func prepareToQuit() async { await model.prepareToQuit() }

    /// Deletes everything Murmur stored on this Mac: dictations, notes (including audio
    /// orphaned by a crash), meetings and voice profiles. Stops any recording first.
    public func deleteAllData() async { await model.deleteAllData() }

    public func window() -> some View { RootView().environment(model) }

    public func detail(for section: String) -> some View {
        SectionDetail(section: SidebarSection(rawValue: section) ?? .home).environment(model)
    }

    public func settings() -> some View { SettingsView().environment(model) }

    public func menuItems() -> some View { MenuItems().environment(model) }
}

struct SectionDetail: View {
    let section: SidebarSection

    var body: some View {
        switch section {
        case .home: HomeView()
        case .meetings: MeetingsView()
        case .library: LibraryView()
        case .setup: SetupView()
        }
    }
}

struct MenuItems: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.isRecordingMeeting {
            Button("● Recording a Meeting…") { model.section = .meetings }
        }
        Button(model.isActive ? "Stop" : "Start Dictation") { model.toggle(.dictation) }
            .keyboardShortcut("d", modifiers: [.control, .option, .command])
        Button("Record a Note") { model.toggle(.note) }
            .disabled(model.isActive)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $model.section) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    status(model.microphone == .granted ? "Microphone on" : "Needs microphone", model.microphone == .granted ? .green : .red)
                    status(model.canPaste ? "Pastes into apps" : "Copies only", model.canPaste ? .green : .orange)
                    status(model.isActive ? "Listening" : "Ready, ⌃⌥⌘D", model.isActive ? .red : .secondary)
                    if model.isRecordingMeeting { status("Recording a meeting", .red) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        } detail: {
            SectionDetail(section: model.section ?? .home)
        }
    }

    private func status(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmDelete = false
    @State private var confirmDeleteEverything = false

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Dictation") {
                Toggle("Clean up text", isOn: $model.cleanup)
                Text("Removes filler words and stutters, fixes punctuation and capitalization.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Restore the clipboard after pasting", isOn: $model.restoreClipboard)
                TextField("Custom words", text: $model.vocabulary, prompt: Text("Names and jargon, comma-separated"))
            }
            Section("Apple Intelligence") {
                Toggle("Use for cleanup and summaries", isOn: $model.useIntelligence)
                    .disabled(!Intelligence.isAvailable)
                LabeledContent("Status", value: Intelligence.status)
                Text("Runs Apple's on-device model. When it's off or unavailable, Murmur uses built-in rules instead.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("History") {
                Toggle("Keep dictations in the Library", isOn: $model.keepHistory)
                Toggle("Also keep dictation audio", isOn: $model.keepDictationAudio)
                    .disabled(!model.keepHistory)
                Picker("Delete recordings older than", selection: $model.retentionDays) {
                    Text("Never").tag(0)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                }
                Text("Dictations keep only their text unless you keep audio; notes keep their audio. Old recordings are deleted when Murmur opens. Everything is stored only in Application Support on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Show in Finder") {
                        try? model.store.prepare()
                        NSWorkspace.shared.open(model.store.directory)
                    }
                    Button("Delete All Recordings…", role: .destructive) { confirmDelete = true }
                        .disabled(model.recordings.isEmpty)
                }
            }
            Section("All Data") {
                Button("Delete All Murmur Data…", role: .destructive) { confirmDeleteEverything = true }
                Text("Removes every dictation, note, meeting and voice profile from this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Delete all \(model.recordings.count) recordings?", isPresented: $confirmDelete) {
            Button("Delete All", role: .destructive) { model.deleteAll() }
        } message: {
            Text("Audio, transcripts and summaries are removed from this Mac. This can't be undone.")
        }
        .confirmationDialog("Delete all Murmur data?", isPresented: $confirmDeleteEverything) {
            Button("Delete Everything", role: .destructive) { Task { await model.deleteAllData() } }
        } message: {
            Text("Dictations, notes, meetings (audio, transcripts, summaries) and voice profiles are removed from this Mac. A recording in progress is stopped and discarded. This can't be undone.")
        }
    }
}
