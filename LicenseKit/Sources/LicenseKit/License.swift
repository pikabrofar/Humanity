import Foundation

/// Humanity apps are free to download and unlocked with a Gumroad license key.
/// One key, stored once, unlocks Humanity and the standalone apps.
public enum License {
    /// Set to false in an update to make every app free.
    public static let required = true

    /// Where people buy a key.
    public static let buyURL = URL(string: "https://gumroad.com/l/hamkad")!
    static let productID = "rUEF1fvaBmPG_LIv3lXMMQ=="
    static let verifyURL = URL(string: "https://api.gumroad.com/v2/licenses/verify")!

    /// Re-check with Gumroad this often, so refunded keys stop working.
    static let recheckAfter: TimeInterval = 7 * 86_400
    /// Keep working offline this long after the last successful check.
    static let offlineGrace: TimeInterval = 60 * 86_400

    struct Stored: Codable, Equatable {
        var key: String
        var verifiedAt: Date
    }

    /// Shared by every Humanity app (not per app), so activating one activates all.
    static var fileURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Humanity/license.json")
    }

    static func load() -> Stored? {
        (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
    }

    static func save(_ stored: Stored?) {
        guard let stored else { try? FileManager.default.removeItem(at: fileURL); return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(stored).write(to: fileURL, options: .atomic)
    }

    /// True when the app may run: no license needed, or a key checked recently enough.
    public static var isUnlocked: Bool {
        !required || load().map { Date().timeIntervalSince($0.verifiedAt) < offlineGrace } ?? false
    }

    /// The first Gumroad-style key in some text, such as the clipboard.
    public static func findKey(in text: String) -> String? {
        text.range(of: #"[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{8}){3}"#, options: .regularExpression)
            .map { text[$0].uppercased() }
    }

    public enum Failure: LocalizedError {
        case rejected(String)
        case network(String)
        public var errorDescription: String? {
            switch self {
            case .rejected(let message), .network(let message): message
            }
        }
    }

    /// Checks a key with Gumroad and stores it when valid.
    /// - Parameter activating: counts as a new activation (shown in Gumroad as "uses").
    public static func activate(_ key: String, activating: Bool = true) async throws {
        var request = URLRequest(url: verifyURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            ("product_id", productID),
            ("license_key", key.trimmingCharacters(in: .whitespacesAndNewlines)),
            ("increment_uses_count", activating ? "true" : "false"),
        ])
        let data: Data
        do {
            data = try await URLSession(configuration: .ephemeral).data(for: request).0
        } catch {
            throw Failure.network("Couldn't reach Gumroad. Check your internet connection and try again.")
        }
        if let problem = problem(in: data) { throw Failure.rejected(problem) }
        save(Stored(key: key, verifiedAt: Date()))
    }

    /// application/x-www-form-urlencoded, escaping everything but unreserved characters
    /// (the product ID contains "=").
    static func formBody(_ fields: [(String, String)]) -> Data {
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(fields.map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: unreserved)!)" }
            .joined(separator: "&").utf8)
    }

    /// Nil when Gumroad's reply says the key is valid; otherwise why not.
    static func problem(in data: Data) -> String? {
        struct Reply: Decodable {
            struct Purchase: Decodable { var refunded: Bool?; var chargebacked: Bool?; var disputed: Bool? }
            var success: Bool
            var message: String?
            var purchase: Purchase?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
            return "Gumroad sent an unexpected reply. Try again in a moment."
        }
        guard reply.success, let purchase = reply.purchase else {
            return "That license key isn't valid. Copy it from your Gumroad receipt and try again."
        }
        if purchase.refunded == true || purchase.chargebacked == true || purchase.disputed == true {
            return "This license was refunded or disputed, so it no longer unlocks Humanity."
        }
        return nil
    }

    /// Quietly re-checks a stored key now and then. Gumroad saying no removes it;
    /// being offline keeps it (until the grace period ends).
    public static func recheckIfDue() async {
        guard required, let stored = load(),
              Date().timeIntervalSince(stored.verifiedAt) > recheckAfter else { return }
        do {
            try await activate(stored.key, activating: false)
        } catch Failure.rejected {
            save(nil)
        } catch {}
    }
}
