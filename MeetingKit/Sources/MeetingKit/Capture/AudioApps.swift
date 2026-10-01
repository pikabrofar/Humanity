import AppKit
import CoreAudio

/// An app whose audio can be recorded, with every Core Audio process that plays sound for it.
public struct AudioApp: Identifiable, Hashable, Sendable {
    public let bundleID: String
    public let name: String
    /// Core Audio process objects (the app plus helpers such as a browser's renderers).
    public let processObjects: [AudioObjectID]
    /// True while any of its processes is sending audio to an output device.
    public let isPlayingAudio: Bool
    public var id: String { bundleID }
}

/// What to record on the second track.
public enum AudioSource: Hashable, Sendable {
    case app(AudioApp)
    /// Everything the Mac plays except the host app itself; for calls in an app that
    /// isn't listed, or when the call's audio comes from an unexpected process.
    case allSystemAudio

    public var displayName: String {
        switch self {
        case .app(let app): app.name
        case .allSystemAudio: "All system audio"
        }
    }

    public var bundleID: String? {
        if case .app(let app) = self { app.bundleID } else { nil }
    }
}

extension AudioApp {
    /// Running apps that have registered with Core Audio, playing ones first.
    /// Requires macOS 14.2 (the process object list); earlier systems list regular
    /// apps without process objects, which only the ScreenCaptureKit path can record.
    public static func running() -> [AudioApp] {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
        let own = Bundle.main.bundleIdentifier
        var objects: [String: [(AudioObjectID, Bool)]] = [:]
        if #available(macOS 14.2, *) {
            for object in CoreAudioHelpers.processObjects() {
                guard let owner = owningApp(of: object, among: apps) else { continue }
                objects[owner, default: []].append((object, CoreAudioHelpers.isRunningOutput(object)))
            }
        }
        return apps.compactMap { app -> AudioApp? in
            guard let bundleID = app.bundleIdentifier, bundleID != own else { return nil }
            let entries = objects[bundleID] ?? []
            if #available(macOS 14.2, *), entries.isEmpty { return nil } // never touched audio
            return AudioApp(bundleID: bundleID, name: app.localizedName ?? bundleID,
                            processObjects: entries.map(\.0), isPlayingAudio: entries.contains { $0.1 })
        }
        .sorted { ($0.isPlayingAudio ? 0 : 1, $0.name) < ($1.isPlayingAudio ? 0 : 1, $1.name) }
    }

    /// Calls often play from a helper process, not the app: Chrome, Edge, Teams and
    /// Discord use `<app id>.helper…`, Safari plays web audio from WebKit's shared GPU
    /// process, and FaceTime audio comes from the system's conferencing daemon.
    private static let knownHelpers = [
        "com.apple.WebKit.GPU": "com.apple.Safari",
        "com.apple.WebKit.WebContent": "com.apple.Safari",
        "com.apple.avconferenced": "com.apple.FaceTime",
    ]

    @available(macOS 14.2, *)
    private static func owningApp(of object: AudioObjectID, among apps: [NSRunningApplication]) -> String? {
        let pid = CoreAudioHelpers.pid(of: object)
        if let app = apps.first(where: { $0.processIdentifier == pid }) { return app.bundleIdentifier }
        guard let bundleID = CoreAudioHelpers.bundleID(of: object), !bundleID.isEmpty else { return nil }
        if let mapped = knownHelpers[bundleID] { return mapped }
        // Longest prefix wins so "com.microsoft.teams2.helper" picks Teams, not another Microsoft app.
        return apps.compactMap(\.bundleIdentifier)
            .filter { bundleID.hasPrefix($0 + ".") }
            .max { $0.count < $1.count }
    }
}

/// Thin wrappers over the Core Audio C property API.
enum CoreAudioHelpers {
    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func read<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T) -> OSStatus {
        var address = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        // Only called with plain values (IDs, numbers, structs, Unmanaged CF refs).
        return withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) }
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var value: Unmanaged<CFString>?
        guard read(object, selector, &value) == noErr else { return nil }
        // Core Audio hands out CF properties retained; the caller releases them.
        return value?.takeRetainedValue() as String?
    }

    @available(macOS 14.2, *)
    static func processObjects() -> [AudioObjectID] {
        var address = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    @available(macOS 14.2, *)
    static func processObject(pid: pid_t) -> AudioObjectID? {
        var address = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                                UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? object : nil
    }

    @available(macOS 14.2, *)
    static func pid(of object: AudioObjectID) -> pid_t {
        var pid: pid_t = -1
        _ = read(object, kAudioProcessPropertyPID, &pid)
        return pid
    }

    @available(macOS 14.2, *)
    static func bundleID(of object: AudioObjectID) -> String? {
        string(object, kAudioProcessPropertyBundleID)
    }

    @available(macOS 14.2, *)
    static func isRunningOutput(_ object: AudioObjectID) -> Bool {
        var running: UInt32 = 0
        _ = read(object, kAudioProcessPropertyIsRunningOutput, &running)
        return running != 0
    }

    static func defaultOutputDeviceUID() -> String? {
        var device = AudioObjectID(kAudioObjectUnknown)
        guard read(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice, &device) == noErr else {
            return nil
        }
        return string(device, kAudioDevicePropertyDeviceUID)
    }
}
