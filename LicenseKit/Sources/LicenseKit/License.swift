import Foundation

/// Humanity apps are free to download and unlocked with a Gumroad license key.
/// One key, stored once, unlocks Humanity and the standalone apps.
public enum License {
    /// Only official release builds (scripts/package.sh) need a key; anyone building
    /// from source gets a free, unlocked app, as the MIT license and Terms promise.
    /// To make the official apps free too, stop passing OFFICIAL=1 in package.sh.
    #if HUMANITY_OFFICIAL
    public static let required = true
    #else
    public static let required = false
    #endif

    /// Where people buy a key.
    public static let buyURL = URL(string: "https://gumroad.com/l/hamkad")!
    public static let termsURL = URL(string: "https://github.com/pikabrofar/Humanity/blob/main/TERMS.md")!
    public static let privacyURL = URL(string: "https://github.com/pikabrofar/Humanity/blob/main/PRIVACY.md")!
    /// Bump when TERMS.md changes materially; people agree again on next launch.
    public static let termsVersion = "2026-10-01"
    static let productID = "rUEF1fvaBmPG_LIv3lXMMQ=="
    static let verifyURL = URL(string: "https://api.gumroad.com/v2/licenses/verify")!

    /// Re-check with Gumroad this often, so refunded keys stop working.
    static let recheckAfter: TimeInterval = 7 * 86_400
    /// Keep working offline this long after the last successful check.
    static let offlineGrace: TimeInterval = 60 * 86_400

    struct Stored: Codable, Equatable {
        var key: String
        var verifiedAt: Date
        /// Which Terms of Sale the person agreed to, and when (kept as a record of assent).
        var termsVersion: String?
        var agreedAt: Date?
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
        guard required else { return true }
        guard let stored = load(), stored.termsVersion == termsVersion else { return false }
        let age = Date().timeIntervalSince(stored.verifiedAt)
        return age > -86_400 && age < offlineGrace // a future date isn't a valid check
    }

    /// The saved key, to prefill the window when only new Terms need agreeing to.
    public static var savedKey: String? { load()?.key }

    /// The first Gumroad-style key in some text, such as the clipboard.
    public static func findKey(in text: String) -> String? {
        text.range(of: #"[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{8}){3}"#, options: .regularExpression)
            .map { text[$0].uppercased() }
    }

    public enum Failure: LocalizedError, Equatable {
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
        // Already verified and only new Terms to agree to: record assent without
        // needing Gumroad (offline or down shouldn't block a paying customer).
        if activating, let stored = load(), stored.key == key,
           Date().timeIntervalSince(stored.verifiedAt) < offlineGrace {
            save(Stored(key: key, verifiedAt: stored.verifiedAt, termsVersion: termsVersion, agreedAt: Date()))
            return
        }
        var request = URLRequest(url: verifyURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            ("product_id", productID),
            ("license_key", key.trimmingCharacters(in: .whitespacesAndNewlines)),
            ("increment_uses_count", activating ? "true" : "false"),
        ])
        let data: Data
        let status: Int
        do {
            let (body, response) = try await URLSession(configuration: .ephemeral).data(for: request)
            data = body
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
        } catch {
            throw Failure.network("Couldn't reach Gumroad. Check your internet connection and try again.")
        }
        if let failure = failure(in: data, status: status) { throw failure }
        let previous = load()
        save(Stored(key: key, verifiedAt: Date(),
                    termsVersion: activating ? termsVersion : previous?.termsVersion,
                    agreedAt: activating ? Date() : previous?.agreedAt))
    }

    /// application/x-www-form-urlencoded, escaping everything but unreserved characters
    /// (the product ID contains "=").
    static func formBody(_ fields: [(String, String)]) -> Data {
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(fields.map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: unreserved)!)" }
            .joined(separator: "&").utf8)
    }

    /// Nil when Gumroad's reply says the key is valid. Only a clear "no" from Gumroad
    /// is `.rejected`; anything unreadable (a captive portal, an outage page) is
    /// treated like being offline, so it never removes a paying customer's key.
    static func failure(in data: Data, status: Int = 200) -> Failure? {
        // Gumroad answers 200 for a known key and 404 for an unknown one; any other
        // status (rate limit, outage) says nothing about the key.
        guard status == 200 || status == 404 else {
            return .network("Gumroad is unavailable right now. Try again in a moment.")
        }
        struct Reply: Decodable {
            struct Purchase: Decodable {
                var refunded: Bool?; var chargebacked: Bool?; var disputed: Bool?; var dispute_won: Bool?
            }
            var success: Bool
            var message: String?
            var purchase: Purchase?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
            return .network("Gumroad sent an unexpected reply. Check your connection and try again.")
        }
        guard reply.success, let purchase = reply.purchase else {
            return .rejected("That license key isn't valid. Copy it from your Gumroad receipt and try again.")
        }
        if purchase.refunded == true || purchase.chargebacked == true
            || (purchase.disputed == true && purchase.dispute_won != true) {
            return .rejected("This license was refunded or disputed, so it no longer unlocks Humanity.")
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
