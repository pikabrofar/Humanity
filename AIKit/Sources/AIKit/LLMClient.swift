import Foundation
import Security

public enum AIError: Error, Equatable, LocalizedError {
    case missingKey(provider: String)
    case http(status: Int, message: String)
    case rateLimited(retryAfter: TimeInterval?, message: String)
    case network(URLError)
    case invalidResponse
    case keychain(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .missingKey(let name): return "No API key for \(name). Add one in Settings."
        case .http(let status, let message): return "HTTP \(status): \(message)"
        case .rateLimited(let after, let message):
            return "Rate limited\(after.map { ", retry in \(Int($0))s" } ?? ""): \(message)"
        case .network(let error): return error.localizedDescription
        case .invalidResponse: return "The provider sent a reply AIKit couldn't read."
        case .keychain(let status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        }
    }
}

/// One provider, one key. Stateless; make one per call or keep it around.
public struct LLMClient: Sendable {
    public let provider: Provider
    private let key: String?
    private let session: URLSession

    /// Ephemeral so replies (which contain transcript content) are never
    /// written to the on-disk URL cache or cookie store.
    public static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120   // non-streaming replies can take a while to start
        config.timeoutIntervalForResource = 300
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    /// Reads the key from the Keychain unless one is passed (e.g. to test a
    /// pasted key before saving it).
    public init(provider: Provider, apiKey: String? = nil, session: URLSession = LLMClient.defaultSession) {
        self.provider = provider
        self.key = apiKey ?? (provider.needsKey ? KeychainStore.read(provider.id) : nil)
        self.session = session
    }

    public func complete(system: String, prompt: String, model: String, maxTokens: Int = 1024) async throws -> String {
        let request = try completionRequest(system: system, prompt: prompt, model: model, maxTokens: maxTokens)
        let data = try await send(request)
        return try Self.parseCompletion(data, api: provider.api)
    }

    /// Model IDs from the provider's own catalog, so the picker never goes stale.
    public func listModels() async throws -> [String] {
        // Anthropic pages at 20 by default.
        let path = provider.api == .anthropic ? "models?limit=1000" : "models"
        let data = try await send(try request(path, body: nil, timeout: 20))
        return try Self.parseModels(data)
    }

    // MARK: - Request building

    func completionRequest(system: String, prompt: String, model: String, maxTokens: Int) throws -> URLRequest {
        var body: [String: Any] = ["model": model]
        switch provider.api {
        case .anthropic:
            body["max_tokens"] = maxTokens
            if !system.isEmpty { body["system"] = system }
            body["messages"] = [["role": "user", "content": prompt]]
            return try request("messages", body: body)
        case .openAI:
            body[provider.maxTokensField] = maxTokens
            body["messages"] = (system.isEmpty ? [] : [["role": "system", "content": system]])
                + [["role": "user", "content": prompt]]
            return try request("chat/completions", body: body)
        }
    }

    func request(_ path: String, body: [String: Any]?, timeout: TimeInterval = 120) throws -> URLRequest {
        var request = URLRequest(url: URL(string: provider.baseURL.absoluteString + "/" + path)!)
        request.timeoutInterval = timeout
        if let body {
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        if provider.needsKey {
            guard let key, !key.isEmpty else { throw AIError.missingKey(provider: provider.name) }
            switch provider.auth {
            case .bearer: request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            case .xAPIKey: request.setValue(key, forHTTPHeaderField: "x-api-key")
            case .none: break
            }
        }
        if provider.api == .anthropic {
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        return request
    }

    // MARK: - Transport and parsing

    // Deliberately no logging anywhere here: requests carry keys and transcripts.
    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            var message = Self.errorMessage(data, status: http.statusCode)
            if let key, !key.isEmpty { message = message.replacingOccurrences(of: key, with: "•••") }
            if http.statusCode == 429 {
                let after = http.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init)
                throw AIError.rateLimited(retryAfter: after, message: message)
            }
            throw AIError.http(status: http.statusCode, message: message)
        }
        return data
    }

    static func parseCompletion(_ data: Data, api: Provider.API) throws -> String {
        let text: String?
        switch api {
        case .anthropic:
            struct Reply: Decodable { struct Block: Decodable { let type: String; let text: String? }; let content: [Block] }
            text = (try? JSONDecoder().decode(Reply.self, from: data))?.content
                .filter { $0.type == "text" }.compactMap(\.text).joined()
        case .openAI:
            struct Reply: Decodable {
                struct Choice: Decodable { struct Message: Decodable { let content: String? }; let message: Message }
                let choices: [Choice]
            }
            text = (try? JSONDecoder().decode(Reply.self, from: data))?.choices.first?.message.content
        }
        guard let text else { throw AIError.invalidResponse }
        return stripThinking(text)
    }

    /// Reasoning models served through compatible APIs (DeepSeek R1, Qwen on
    /// Groq/Ollama) inline their scratchpad; callers want only the answer.
    static func stripThinking(_ text: String) -> String {
        text.replacingOccurrences(of: "(?s)<think>.*?</think>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseModels(_ data: Data) throws -> [String] {
        struct Model: Decodable { let id: String }
        struct List: Decodable { let data: [Model] }
        // Together returns a bare array instead of `{ "data": [...] }`.
        guard let models = (try? JSONDecoder().decode(List.self, from: data).data)
                ?? (try? JSONDecoder().decode([Model].self, from: data)) else { throw AIError.invalidResponse }
        // Gemini prefixes IDs with "models/"; drop models that can't chat.
        let nonChat = try! NSRegularExpression(pattern: "embed|tts|whisper|dall-e|moderation|transcribe|realtime|image|audio|guard", options: .caseInsensitive)
        return models.map { $0.id.hasPrefix("models/") ? String($0.id.dropFirst(7)) : $0.id }
            .filter { nonChat.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) == nil }
            .sorted()
    }

    /// Error bodies differ: OpenAI/Anthropic `{"error":{"message":…}}`, Ollama
    /// `{"error":"…"}`, Gemini wraps in an array, Mistral sometimes `{"message":…}`.
    static func errorMessage(_ data: Data, status: Int) -> String {
        var json = try? JSONSerialization.jsonObject(with: data)
        if let array = json as? [Any] { json = array.first }
        let object = json as? [String: Any]
        let message = (object?["error"] as? [String: Any])?["message"] as? String
            ?? object?["error"] as? String
            ?? object?["message"] as? String
            ?? object?["detail"] as? String
        return String((message ?? HTTPURLResponse.localizedString(forStatusCode: status)).prefix(300))
    }
}
