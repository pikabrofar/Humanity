import SwiftUI

/// First-run quick setup: microphone → speech recognition → Accessibility → try it.
/// Also reachable from the sidebar at any time.
struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var sample = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Setup").font(.largeTitle.weight(.semibold))
                    Text("Three permissions, under a minute. Speech is recognized on this Mac; your audio never leaves it.")
                        .foregroundStyle(.secondary)
                }

                StepCard(number: 1, title: "Microphone", done: model.microphone == .granted,
                         detail: "bocaS listens only while you dictate or record, and shows the pill at the bottom of the screen whenever it does.") {
                    permissionButtons(model.microphone, allow: "Allow Microphone", pane: .microphone) {
                        _ = await Permissions.requestMicrophone()
                    }
                }

                StepCard(number: 2, title: "Speech Recognition", done: model.speech == .granted,
                         detail: "macOS asks before any app transcribes speech. bocaS only uses on-device recognition and never falls back to Apple's servers.") {
                    permissionButtons(model.speech, allow: "Allow Speech Recognition", pane: .speech) {
                        _ = await Permissions.requestSpeech()
                    }
                }

                StepCard(number: 3, title: "Accessibility (for pasting)", done: model.canPaste,
                         detail: "Lets bocaS press ⌘V for you in the app you're dictating into. Without it, text is copied and you paste it yourself.") {
                    if !model.canPaste {
                        HStack {
                            Button("Grant Access") { Permissions.requestPaste() }
                                .buttonStyle(.borderedProminent)
                            Button("Open Accessibility Settings") { SystemSettings.open(.accessibility) }
                        }
                        Text("Already on but not working? After an update, remove bocaS from the list with – and add it again.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                StepCard(number: 4, title: "Try it", done: !sample.isEmpty,
                         detail: "Click in the box, press ⌃⌥⌘D, say a sentence, then press ⌃⌥⌘D again. Or hold the keys while you talk.") {
                    TextEditor(text: $sample)
                        .font(.body)
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                }

                HStack {
                    Spacer()
                    Button {
                        model.completeSetup()
                    } label: {
                        Label("Done", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.microphone != .granted)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Quick Setup")
    }

    @ViewBuilder
    private func permissionButtons(_ state: Permission, allow: String, pane: SystemSettings.Pane,
                                   request: @escaping () async -> Void) -> some View {
        switch state {
        case .granted:
            EmptyView()
        case .undetermined:
            Button(allow) {
                Task {
                    await request()
                    model.refreshPermissions()
                }
            }
            .buttonStyle(.borderedProminent)
        case .denied:
            Button("Open Privacy Settings") { SystemSettings.open(pane) }
        }
    }
}

private struct StepCard<Content: View>: View {
    let number: Int
    let title: String
    let done: Bool
    let detail: String
    @ViewBuilder var content: Content

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(done ? Color.green : Color.accentColor.opacity(0.15))
                    if done {
                        Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                    } else {
                        Text("\(number)").font(.headline).foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.headline)
                    Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    content
                }
                Spacer(minLength: 0)
            }
        }
        .animation(.default, value: done)
    }
}
