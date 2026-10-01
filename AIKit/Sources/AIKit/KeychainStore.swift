import Foundation
import Security

/// API keys live only in the user's Keychain, one generic password per
/// provider, so they are encrypted at rest and never touch UserDefaults or disk.
public enum KeychainStore {
    public static let service = "io.github.pikabrofar.humanity.ai"

    public static func save(_ key: String, for providerID: String) throws {
        delete(providerID)  // add-after-delete is simpler than SecItemUpdate's two-dictionary dance
        let status = SecItemAdd(query(providerID).merging([
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]) { $1 } as CFDictionary, nil)
        guard status == errSecSuccess else { throw AIError.keychain(status) }
    }

    public static func read(_ providerID: String) -> String? {
        var result: AnyObject?
        let status = SecItemCopyMatching(query(providerID).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { $1 } as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Existence check that never decrypts the secret, so listing which
    /// providers are connected can't trigger a Keychain access prompt.
    public static func contains(_ providerID: String) -> Bool {
        SecItemCopyMatching(query(providerID) as CFDictionary, nil) == errSecSuccess
    }

    public static func delete(_ providerID: String) {
        SecItemDelete(query(providerID) as CFDictionary)
    }

    private static func query(_ providerID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
        ]
    }
}
