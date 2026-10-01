import Foundation

/// A cloud (or local) LLM service the user can connect with their own key.
public struct Provider: Identifiable, Hashable, Sendable {
    /// Wire format. Nearly everyone copied OpenAI's Chat Completions, so one
    /// code path covers all but Anthropic.
    public enum API: Sendable { case openAI, anthropic }

    public enum Auth: Sendable {
        case bearer      // Authorization: Bearer <key>
        case xAPIKey     // x-api-key: <key> (Anthropic)
        case none        // local servers
    }

    public let id: String
    public let name: String
    public let baseURL: URL
    public let api: API
    public let auth: Auth
    /// Starting point only; users pick current models from `LLMClient.listModels()`.
    public let defaultModel: String
    public let keyURL: URL
    /// Chunk size for long transcripts. Cloud models take far more, but free
    /// tiers cap tokens per minute; Ollama silently truncates past its small
    /// default context.
    public let chunkCharacters: Int
    /// OpenAI's newer models reject `max_tokens`; most compatible servers
    /// still only know `max_tokens`.
    let maxTokensField: String

    public var needsKey: Bool { auth != .none }

    init(_ id: String, _ name: String, _ base: String, api: API = .openAI, auth: Auth = .bearer,
         model: String, keyURL: String, chunk: Int = 24_000, maxTokensField: String = "max_tokens") {
        self.id = id
        self.name = name
        self.baseURL = URL(string: base)!
        self.api = api
        self.auth = auth
        self.defaultModel = model
        self.keyURL = URL(string: keyURL)!
        self.chunkCharacters = chunk
        self.maxTokensField = maxTokensField
    }

    public static let all: [Provider] = [
        Provider("groq", "Groq", "https://api.groq.com/openai/v1",
                 model: "llama-3.3-70b-versatile", keyURL: "https://console.groq.com/keys", chunk: 16_000),
        Provider("gemini", "Google Gemini", "https://generativelanguage.googleapis.com/v1beta/openai",
                 model: "gemini-2.5-flash", keyURL: "https://aistudio.google.com/apikey"),
        Provider("openai", "OpenAI", "https://api.openai.com/v1",
                 model: "gpt-5-mini", keyURL: "https://platform.openai.com/api-keys",
                 maxTokensField: "max_completion_tokens"),
        Provider("anthropic", "Anthropic", "https://api.anthropic.com/v1", api: .anthropic, auth: .xAPIKey,
                 model: "claude-sonnet-5-5", keyURL: "https://console.anthropic.com/settings/keys"),
        Provider("openrouter", "OpenRouter", "https://openrouter.ai/api/v1",
                 model: "openrouter/auto", keyURL: "https://openrouter.ai/keys"),
        Provider("mistral", "Mistral", "https://api.mistral.ai/v1",
                 model: "mistral-small-latest", keyURL: "https://console.mistral.ai/api-keys"),
        Provider("deepseek", "DeepSeek", "https://api.deepseek.com/v1",
                 model: "deepseek-chat", keyURL: "https://platform.deepseek.com/api_keys"),
        Provider("together", "Together", "https://api.together.xyz/v1",
                 model: "meta-llama/Llama-3.3-70B-Instruct-Turbo", keyURL: "https://api.together.ai/settings/api-keys"),
        Provider("xai", "xAI", "https://api.x.ai/v1",
                 model: "grok-3-mini", keyURL: "https://console.x.ai"),
        Provider("ollama", "Ollama (local)", "http://localhost:11434/v1", auth: .none,
                 model: "llama3.2", keyURL: "https://ollama.com/download", chunk: 8_000),
    ]

    public static func named(_ id: String) -> Provider? { all.first { $0.id == id } }

    /// The faster, cheaper Claude for high-volume work like dictation cleanup.
    public static let anthropicFastModel = "claude-haiku-4-5-20251001"
}
