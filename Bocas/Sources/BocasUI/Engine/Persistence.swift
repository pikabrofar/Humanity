import AppKit
import AVFoundation
import Speech

/// Typed UserDefaults keys. SwiftUI's @AppStorage doesn't work inside @Observable models.
enum Defaults {
    enum Key: String {
        case completedSetup, cleanup, useIntelligence, keepHistory, restoreClipboard, vocabulary
        case keepDictationAudio, retentionDays

        /// Prefixed so modules can share one defaults domain inside Sentidos.
        var name: String { "Bocas." + rawValue }
    }

    static func bool(_ key: Key, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key.name) as? Bool ?? value
    }
    static func int(_ key: Key) -> Int { UserDefaults.standard.integer(forKey: key.name) }
    static func string(_ key: Key) -> String { UserDefaults.standard.string(forKey: key.name) ?? "" }
    static func set(_ value: Any?, _ key: Key) { UserDefaults.standard.set(value, forKey: key.name) }
}

enum Permission { case granted, denied, undetermined }

/// Deliberately not on the main actor: the system calls these completion
/// handlers on background queues.
enum Permissions {
    static var microphone: Permission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .undetermined
        default: .denied
        }
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static var speech: Permission {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .notDetermined: .undetermined
        default: .denied
        }
    }

    static func requestSpeech() async -> Bool {
        await withCheckedContinuation { done in
            SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0 == .authorized) }
        }
    }

    /// Posting ⌘V needs Accessibility. The two checks can disagree right after
    /// granting, so either one is enough.
    static var canPaste: Bool { CGPreflightPostEventAccess() || AXIsProcessTrusted() }

    /// Shows the system prompt once; afterwards the user must use System Settings.
    static func requestPaste() { _ = CGRequestPostEventAccess() }
}

enum SystemSettings {
    enum Pane: String {
        case microphone = "Privacy_Microphone"
        case speech = "Privacy_SpeechRecognition"
        case accessibility = "Privacy_Accessibility"
    }

    static func open(_ pane: Pane) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)")!)
    }
}
