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
    /// One line on what the provider does with the text, from its terms (see legal/research/13).
    public let dataUse: String
    /// Chunk size for long transcripts. Cloud models take far more, but free
    /// tiers cap tokens per minute; Ollama silently truncates past its small
    /// default context.
    public let chunkCharacters: Int
    /// OpenAI's newer models reject `max_tokens`; most compatible servers
    /// still only know `max_tokens`.
    let maxTokensField: String

    public var needsKey: Bool { auth != .none }

    init(_ id: String, _ name: String, _ base: String, api: API = .openAI, auth: Auth = .bearer,
         model: String, keyURL: String, dataUse: String, chunk: Int = 24_000, maxTokensField: String = "max_tokens") {
        self.id = id
        self.name = name
        self.baseURL = URL(string: base)!
        self.api = api
        self.auth = auth
        self.defaultModel = model
        self.keyURL = URL(string: keyURL)!
        self.dataUse = dataUse
        self.chunkCharacters = chunk
        self.maxTokensField = maxTokensField
    }

    public static let all: [Provider] = [
        Provider("groq", "Groq", "https://api.groq.com/openai/v1",
                 model: "llama-3.3-70b-versatile", keyURL: "https://console.groq.com/keys",
                 dataUse: "Logs may be kept up to 30 days for troubleshooting; not used for training without permission.", chunk: 16_000),
        Provider("gemini", "Google Gemini", "https://generativelanguage.googleapis.com/v1beta/openai",
                 model: "gemini-2.5-flash", keyURL: "https://aistudio.google.com/apikey",
                 dataUse: "Free keys: Google may use your text to improve its products, and people may review it."),
        Provider("openai", "OpenAI", "https://api.openai.com/v1",
                 model: "gpt-5-mini", keyURL: "https://platform.openai.com/api-keys",
                 dataUse: "API data is kept about 30 days for abuse checks; not used for training unless you opt in.",
                 maxTokensField: "max_completion_tokens"),
        Provider("anthropic", "Anthropic", "https://api.anthropic.com/v1", api: .anthropic, auth: .xAPIKey,
                 model: "claude-sonnet-5-5", keyURL: "https://console.anthropic.com/settings/keys",
                 dataUse: "API data is kept about 30 days (longer if flagged); not used for training."),
        Provider("openrouter", "OpenRouter", "https://openrouter.ai/api/v1",
                 model: "openrouter/auto", keyURL: "https://openrouter.ai/keys",
                 dataUse: "May route to upstream providers with their own retention and training policies."),
        Provider("mistral", "Mistral", "https://api.mistral.ai/v1",
                 model: "mistral-small-latest", keyURL: "https://console.mistral.ai/api-keys",
                 dataUse: "Free tier may be used for training unless you opt out; paid tiers keep data about 30 days."),
        Provider("deepseek", "DeepSeek", "https://api.deepseek.com/v1",
                 model: "deepseek-chat", keyURL: "https://platform.deepseek.com/api_keys",
                 dataUse: "May be stored on servers in China, and may be used for training."),
        Provider("together", "Together", "https://api.together.xyz/v1",
                 model: "meta-llama/Llama-3.3-70B-Instruct-Turbo", keyURL: "https://api.together.ai/settings/api-keys",
                 dataUse: "Data use not reviewed; check its terms before sending private text."),
        Provider("xai", "xAI", "https://api.x.ai/v1",
                 model: "grok-3-mini", keyURL: "https://console.x.ai",
                 dataUse: "Deleted within about 30 days; not used for training without permission."),
        Provider("ollama", "Ollama (local)", "http://localhost:11434/v1", auth: .none,
                 model: "llama3.2", keyURL: "https://ollama.com/download",
                 dataUse: "Runs on your Mac; nothing goes to a third party.", chunk: 8_000),
    ]

    public static func named(_ id: String) -> Provider? { all.first { $0.id == id } }

    /// The faster, cheaper Claude for high-volume work like dictation cleanup.
    public static let anthropicFastModel = "claude-haiku-4-5-20251001"
}
