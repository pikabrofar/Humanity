import Foundation
import HandKit

/// Typed UserDefaults keys. SwiftUI's @AppStorage doesn't work inside @Observable models.
enum Defaults {
    enum Key: String {
        case leftHanded, showHUD, completedSetup, profile

        /// Prefixed so modules can share one defaults domain inside Sentidos.
        var name: String { "Manos." + rawValue }
    }

    static func bool(_ key: Key, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key.name) as? Bool ?? value
    }
    static func set(_ value: Any?, _ key: Key) { UserDefaults.standard.set(value, forKey: key.name) }
}

enum ProfileStore {
    static func load() -> HandProfile {
        guard let data = UserDefaults.standard.data(forKey: Defaults.Key.profile.name),
              let profile = try? JSONDecoder().decode(HandProfile.self, from: data)
        else { return HandProfile() }
        return profile
    }

    static func save(_ profile: HandProfile) {
        Defaults.set(try? JSONEncoder().encode(profile), .profile)
    }
}
