# AIKit

Bring-your-own-key LLM access for the Humanity apps: summarizing meeting and
call transcripts, cleaning up dictation, extracting action items, and anything
else a module needs a model for.

On-device Apple Intelligence stays the default. A cloud provider is used only
after the user adds a key **and** picks that provider for a task.

- `AIKit`: providers, Keychain storage, the HTTP client, settings and ready-made tasks. No UI.
- `AIKitUI`: `AIProvidersView`, a compact SwiftUI settings screen.

Swift 5.10, macOS 14+, Command Line Tools only, no dependencies beyond the SDK (URLSession, Security, NaturalLanguage).

```sh
swift build
make test   # Swift Testing; works without Xcode
```

## Using it from a module

```swift
// Package.swift
.package(path: "../AIKit"),
.target(name: "MurmurUI", dependencies: [.product(name: "AIKit", package: "AIKit")])
```

```swift
import AIKit

// Uses whatever the user chose for .summaries. nil means "on-device", so
// fall back to Apple Intelligence or your own extractive summary.
if let summary = try await Tasks.summarize(transcript: text) {
    show(summary.text, summary.actionItems, summary.speakers)
} else {
    show(await Intelligence.summarize(text) ?? Summarizer.extractive(text))
}

// Dictation cleanup, same pattern.
let cleaned = try await Tasks.cleanup(dictation) ?? localPolish(dictation)

// Any other prompt, routed through the user's choice for a task.
let reply = try await Tasks.complete(.general, system: "Extract dates as a list.", prompt: notes)

// Or talk to a specific provider directly.
let client = LLMClient(provider: Provider.named("anthropic")!)   // key comes from the Keychain
let models = try await client.listModels()
let text = try await client.complete(system: "Be brief.", prompt: "…", model: "claude-sonnet-5-5", maxTokens: 512)
```

Errors are `AIError`: `.missingKey`, `.http(status:message:)` (with the
provider's own message), `.rateLimited(retryAfter:message:)`, `.network(URLError)`,
`.invalidResponse`, `.keychain(OSStatus)`. All have a readable `localizedDescription`.

Settings screen:

```swift
import AIKitUI
Settings { AIProvidersView() }   // or a tab inside your existing settings
```

`Tasks.summarize` splits long transcripts at line, then sentence, boundaries
(hard-splitting unpunctuated text), condenses each chunk, then summarizes the
notes (map-reduce). When most lines look like `Name: text`, it also asks for
one line per speaker. Chunk size comes from the provider (`chunkCharacters`).

## Providers

| ID | Provider | API | Default model | Key |
|---|---|---|---|---|
| `groq` | Groq | OpenAI-compatible | `llama-3.3-70b-versatile` | [console.groq.com/keys](https://console.groq.com/keys) |
| `gemini` | Google Gemini | OpenAI-compatible (`/v1beta/openai`) | `gemini-2.5-flash` | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| `openai` | OpenAI | Chat Completions | `gpt-5-mini` | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| `anthropic` | Anthropic | Messages API | `claude-sonnet-5-5` (fast: `claude-haiku-4-5-20251001`) | [console.anthropic.com](https://console.anthropic.com/settings/keys) |
| `openrouter` | OpenRouter | OpenAI-compatible | `openrouter/auto` | [openrouter.ai/keys](https://openrouter.ai/keys) |
| `mistral` | Mistral | OpenAI-compatible | `mistral-small-latest` | [console.mistral.ai](https://console.mistral.ai/api-keys) |
| `deepseek` | DeepSeek | OpenAI-compatible | `deepseek-chat` | [platform.deepseek.com](https://platform.deepseek.com/api_keys) |
| `together` | Together | OpenAI-compatible | `meta-llama/Llama-3.3-70B-Instruct-Turbo` | [api.together.ai](https://api.together.ai/settings/api-keys) |
| `xai` | xAI | OpenAI-compatible | `grok-3-mini` | [console.x.ai](https://console.x.ai) |
| `ollama` | Ollama (local) | OpenAI-compatible, `localhost:11434` | `llama3.2` | none needed |

Defaults are only a starting point. The model picker is filled from each
provider's own `/models` endpoint, and any model ID can be typed in.

## Privacy

- **Default is on-device.** Every task starts as `.onDevice`; nothing is sent anywhere until the user picks a provider.
- **What is sent:** the text of the transcript or note (and the instructions) goes to the chosen provider, under that provider's terms. **Audio is never sent.** Ollama stays on this Mac.
- **Keys** are stored only in the macOS Keychain (generic password, service `io.github.pikabrofar.humanity.ai`, account = provider ID), never in UserDefaults, files or logs. Provider error messages are scrubbed of the key before they reach the UI.
- **No logging** of keys, prompts or replies. Requests use an ephemeral `URLSession`, so nothing is cached to disk.
- **Testing a key** lists models; it sends no content and costs no tokens.
- Settings (`AIKit.settings` in UserDefaults) hold only provider and model IDs.
