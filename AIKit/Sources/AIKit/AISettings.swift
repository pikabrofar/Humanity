import Foundation

/// Things other modules ask a model to do; each can use a different engine.
public enum AITask: String, Codable, CaseIterable, Identifiable, Sendable {
    case summaries, cleanup, general

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .summaries: return "Summaries & action items"
        case .cleanup: return "Dictation cleanup"
        case .general: return "Other tasks"
        }
    }
}

public enum AIEngine: Codable, Hashable, Sendable {
    /// Apple Intelligence or the caller's local fallback. Nothing leaves the Mac.
    case onDevice
    case provider(id: String, model: String)
}

/// Which engine each task uses. Holds no secrets, so UserDefaults is fine.
public struct AISettings: Codable, Equatable, Sendable {
    public static let defaultsKey = "AIKit.settings"

    /// Keyed by task raw value so adding a task never breaks decoding old data.
    public var engines: [String: AIEngine] = [:]

    public init() {}

    /// Cloud is strictly opt-in: anything unset is on-device.
    public subscript(task: AITask) -> AIEngine {
        get { engines[task.rawValue] ?? .onDevice }
        set { engines[task.rawValue] = newValue }
    }

    public static func load(_ defaults: UserDefaults = .standard) -> AISettings {
        defaults.data(forKey: defaultsKey).flatMap { try? JSONDecoder().decode(AISettings.self, from: $0) } ?? AISettings()
    }

    public func save(_ defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
