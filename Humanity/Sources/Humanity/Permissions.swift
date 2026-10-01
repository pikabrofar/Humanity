import ApplicationServices
import AVFoundation
import Observation
import Speech
import SwiftUI

/// Every macOS permission the suite needs, granted once to Humanity. All
/// modules run inside this one app, so they share these grants: there's one
/// Humanity entry in System Settings, not one per module.
@MainActor @Observable
final class SuitePermissions {
    enum Kind: String, CaseIterable, Identifiable {
        case camera, microphone, speech, accessibility, screenRecording
        var id: Self { self }

        var title: String {
            switch self {
            case .camera: "Camera"
            case .microphone: "Microphone"
            case .speech: "Speech Recognition"
            case .accessibility: "Accessibility"
            case .screenRecording: "Screen Recording"
            }
        }

        var symbol: String {
            switch self {
            case .camera: "camera"
            case .microphone: "mic"
            case .speech: "text.bubble"
            case .accessibility: "accessibility"
            case .screenRecording: "rectangle.dashed.badge.record"
            }
        }

        /// Why, and which modules use it.
        var reason: String {
            switch self {
            case .camera: "OculOS tracks your eyes and ManOS your hands. Frames never leave this Mac."
            case .microphone: "Murmur listens while you dictate or record a note."
            case .speech: "Murmur turns speech into text with Apple's on-device recognizer."
            case .accessibility: "ManOS moves the pointer and clicks; Murmur pastes your dictation."
            case .screenRecording: "Optional: OculOS shows what you looked at behind gaze heatmaps."
            }
        }

        var isOptional: Bool { self == .screenRecording }

        var settingsPane: String {
            switch self {
            case .camera: "Privacy_Camera"
            case .microphone: "Privacy_Microphone"
            case .speech: "Privacy_SpeechRecognition"
            case .accessibility: "Privacy_Accessibility"
            case .screenRecording: "Privacy_ScreenCapture"
            }
        }
    }

    enum State { case granted, notAsked, denied }

    private(set) var states: [Kind: State] = [:]
    @ObservationIgnored private var timer: Timer?

    init() {
        refresh()
        // macOS has no callback when a permission is toggled in System Settings.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    var missingRequired: [Kind] { Kind.allCases.filter { !$0.isOptional && states[$0] != .granted } }

    func refresh() {
        for kind in Kind.allCases { states[kind] = Self.state(of: kind) }
    }

    func request(_ kind: Kind) {
        switch (kind, states[kind]) {
        case (.camera, .notAsked):
            Task { _ = await AVCaptureDevice.requestAccess(for: .video); refresh() }
        case (.microphone, .notAsked):
            Task { _ = await AVCaptureDevice.requestAccess(for: .audio); refresh() }
        case (.speech, .notAsked):
            SFSpeechRecognizer.requestAuthorization { _ in
                Task { @MainActor in self.refresh() }
            }
        case (.accessibility, _):
            // Adds Humanity to the Accessibility list and shows the system prompt.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            if !AXIsProcessTrustedWithOptions(options) { openSettings(kind) }
        case (.screenRecording, _):
            if !CGRequestScreenCaptureAccess() { openSettings(kind) }
        default:
            // Already denied: only System Settings can change it now.
            openSettings(kind)
        }
    }

    func openSettings(_ kind: Kind) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(kind.settingsPane)")!)
    }

    private static func state(of kind: Kind) -> State {
        switch kind {
        case .camera: av(.video)
        case .microphone: av(.audio)
        case .speech:
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: .granted
            case .notDetermined: .notAsked
            default: .denied
            }
        case .accessibility: AXIsProcessTrusted() ? .granted : .notAsked
        case .screenRecording: CGPreflightScreenCaptureAccess() ? .granted : .notAsked
        }
    }

    private static func av(_ type: AVMediaType) -> State {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }
}

struct PermissionsView: View {
    @Environment(SuitePermissions.self) private var permissions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Grant these once and every module can use them. They all belong to Humanity, so System Settings lists a single app.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(SuitePermissions.Kind.allCases) { kind in
                    PermissionRow(kind: kind, state: permissions.states[kind] ?? .notAsked) {
                        permissions.request(kind)
                    }
                }
                Text("Using the standalone OculOS, ManOS or Murmur apps too? They're separate apps to macOS with their own entries. You only need Humanity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: 620, alignment: .leading)
        }
        .navigationTitle("Permissions")
    }
}

private struct PermissionRow: View {
    let kind: SuitePermissions.Kind
    let state: SuitePermissions.State
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(kind.title).font(.callout.weight(.semibold))
                    if kind.isOptional { Text("Optional").font(.caption2).foregroundStyle(.secondary) }
                }
                Text(kind.reason).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if state == .granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
                    .font(.title3)
                    .help("Granted")
            } else {
                Button(state == .denied ? "Open Settings" : "Grant", action: action)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.default, value: state)
    }
}
