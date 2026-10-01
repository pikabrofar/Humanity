import Foundation
import Testing
@testable import AIKit

private let groq = Provider.named("groq")!
private let openAI = Provider.named("openai")!
private let anthropic = Provider.named("anthropic")!
private let ollama = Provider.named("ollama")!

private func json(_ request: URLRequest) -> NSDictionary? {
    request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? NSDictionary }
}

// MARK: - Catalog

@Test func catalogIsConsistent() {
    #expect(Set(Provider.all.map(\.id)).count == Provider.all.count)
    #expect(anthropic.api == .anthropic && anthropic.auth == .xAPIKey)
    #expect(anthropic.defaultModel == "claude-sonnet-5-5")
    #expect(!ollama.needsKey && ollama.baseURL.absoluteString == "http://localhost:11434/v1")
    #expect(Provider.all.filter { $0.api == .anthropic }.count == 1)
    #expect(Provider.all.allSatisfy { !$0.dataUse.isEmpty })
}

@Test func redirectsStayOnTheSameHost() {
    let api = URL(string: "https://api.anthropic.com/v1/messages")
    #expect(RedirectPolicy.allows(from: api, to: URL(string: "https://api.anthropic.com/v1/other")))
    #expect(!RedirectPolicy.allows(from: api, to: URL(string: "https://evil.example/v1/messages")))
    #expect(!RedirectPolicy.allows(from: api, to: URL(string: "http://api.anthropic.com/v1/messages")))
    #expect(!RedirectPolicy.allows(from: api, to: URL(string: "https://api.anthropic.com:8443/v1/messages")))
    #expect(!RedirectPolicy.allows(from: api, to: nil))
}

@Test func providerNameOnlyForCloudTasks() {
    var settings = AISettings()
    #expect(Tasks.providerName(for: .summaries, settings: settings) == nil)
    settings[.summaries] = .provider(id: "anthropic", model: "m")
    #expect(Tasks.providerName(for: .summaries, settings: settings) == "Anthropic")
}

// MARK: - Request building

@Test func openAICompatibleRequest() throws {
    let request = try LLMClient(provider: groq, apiKey: "k-123")
        .completionRequest(system: "Be brief.", prompt: "Hello", model: "llama-3.3-70b-versatile", maxTokens: 50)
    #expect(request.url?.absoluteString == "https://api.groq.com/openai/v1/chat/completions")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer k-123")
    #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == nil)
    #expect(json(request) == [
        "model": "llama-3.3-70b-versatile",
        "max_tokens": 50,
        "messages": [["role": "system", "content": "Be brief."], ["role": "user", "content": "Hello"]],
    ] as NSDictionary)
}

@Test func openAIUsesMaxCompletionTokensAndSkipsEmptySystem() throws {
    let body = json(try LLMClient(provider: openAI, apiKey: "k")
        .completionRequest(system: "", prompt: "Hi", model: "gpt-5-mini", maxTokens: 9))
    #expect(body?["max_completion_tokens"] as? Int == 9)
    #expect(body?["max_tokens"] == nil)
    #expect((body?["messages"] as? [Any])?.count == 1)
}

@Test func anthropicRequest() throws {
    let request = try LLMClient(provider: anthropic, apiKey: "sk-ant")
        .completionRequest(system: "Be brief.", prompt: "Hello", model: "claude-sonnet-5-5", maxTokens: 64)
    #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant")
    #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(json(request) == [
        "model": "claude-sonnet-5-5",
        "max_tokens": 64,
        "system": "Be brief.",
        "messages": [["role": "user", "content": "Hello"]],
    ] as NSDictionary)
}

@Test func ollamaNeedsNoKey() throws {
    let request = try LLMClient(provider: ollama).completionRequest(system: "", prompt: "Hi", model: "llama3.2", maxTokens: 5)
    #expect(request.url?.absoluteString == "http://localhost:11434/v1/chat/completions")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test func missingKeyThrows() {
    #expect(throws: AIError.missingKey(provider: "Groq")) {
        try LLMClient(provider: groq, apiKey: "").completionRequest(system: "", prompt: "x", model: "m", maxTokens: 1)
    }
}

// MARK: - Response parsing

@Test func parsesCompletions() throws {
    let openAIReply = #"{"choices":[{"message":{"role":"assistant","content":"<think>hmm</think>\n Hi there"}}]}"#
    #expect(try LLMClient.parseCompletion(Data(openAIReply.utf8), api: .openAI) == "Hi there")
    let anthropicReply = #"{"content":[{"type":"thinking","thinking":"..."},{"type":"text","text":"Hello"},{"type":"text","text":" world"}]}"#
    #expect(try LLMClient.parseCompletion(Data(anthropicReply.utf8), api: .anthropic) == "Hello world")
    #expect(throws: AIError.invalidResponse) { try LLMClient.parseCompletion(Data("{}".utf8), api: .openAI) }
}

@Test func parsesModelLists() throws {
    let openAIStyle = #"{"object":"list","data":[{"id":"gpt-5-mini"},{"id":"text-embedding-3-small"},{"id":"gpt-4o"},{"id":"whisper-1"}]}"#
    #expect(try LLMClient.parseModels(Data(openAIStyle.utf8)) == ["gpt-4o", "gpt-5-mini"])
    let together = #"[{"id":"b-model","type":"chat"},{"id":"a-model"}]"#
    #expect(try LLMClient.parseModels(Data(together.utf8)) == ["a-model", "b-model"])
    let gemini = #"{"data":[{"id":"models/gemini-2.5-flash"}]}"#
    #expect(try LLMClient.parseModels(Data(gemini.utf8)) == ["gemini-2.5-flash"])
}

@Test(arguments: [
    (#"{"error":{"message":"Invalid API key","type":"invalid_request_error"}}"#, "Invalid API key"),
    (#"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#, "invalid x-api-key"),
    (#"[{"error":{"code":400,"message":"API key not valid"}}]"#, "API key not valid"),
    (#"{"error":"model 'nope' not found"}"#, "model 'nope' not found"),
    (#"{"message":"Unauthorized"}"#, "Unauthorized"),
    ("<html>Bad Gateway</html>", "bad gateway"),
])
func parsesErrorBodies(body: String, expected: String) {
    #expect(LLMClient.errorMessage(Data(body.utf8), status: 502) == expected)
}

// MARK: - Transport (stubbed, no real network)

final class StubProtocol: URLProtocol {
    static var handler: (URLRequest) throws -> (Int, [String: String], Data) = { _ in (200, [:], Data()) }
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        // URLSession hands bodies to protocols as streams.
        var request = request
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while case let count = stream.read(&buffer, maxLength: buffer.count), count > 0 { data.append(buffer, count: count) }
            stream.close()
            request.httpBody = data
        }
        Self.requests.append(request)
        do {
            let (status, headers, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    static func session(_ handler: @escaping (URLRequest) throws -> (Int, [String: String], Data)) -> URLSession {
        self.handler = handler
        requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }
}

@Suite(.serialized) struct Transport {
    @Test func completesThroughSession() async throws {
        let session = StubProtocol.session { _ in (200, [:], Data(#"{"content":[{"type":"text","text":"ok"}]}"#.utf8)) }
        let reply = try await LLMClient(provider: anthropic, apiKey: "k", session: session)
            .complete(system: "s", prompt: "p", model: "claude-haiku-4-5-20251001", maxTokens: 1)
        #expect(reply == "ok")
        #expect(json(StubProtocol.requests[0])?["model"] as? String == "claude-haiku-4-5-20251001")
    }

    @Test func httpErrorsCarryProviderMessageWithoutKey() async {
        let session = StubProtocol.session { _ in
            (401, [:], Data(#"{"error":{"message":"Incorrect API key provided: secret-key"}}"#.utf8))
        }
        await #expect(throws: AIError.http(status: 401, message: "Incorrect API key provided: •••")) {
            try await LLMClient(provider: openAI, apiKey: "secret-key", session: session).listModels()
        }
    }

    @Test func rateLimitIsTyped() async {
        let session = StubProtocol.session { _ in (429, ["Retry-After": "7"], Data(#"{"error":{"message":"Slow down"}}"#.utf8)) }
        await #expect(throws: AIError.rateLimited(retryAfter: 7, message: "Slow down")) {
            try await LLMClient(provider: groq, apiKey: "k", session: session).complete(system: "", prompt: "p", model: "m")
        }
    }

    @Test func networkFailuresAreTyped() async {
        let session = StubProtocol.session { _ in throw URLError(.cannotConnectToHost) }
        await #expect {
            try await LLMClient(provider: ollama, session: session).listModels()
        } throws: { error in
            // URLSession adds task details to userInfo, so compare codes only.
            if case AIError.network(let urlError) = error { return urlError.code == .cannotConnectToHost }
            return false
        }
    }

    @Test func anthropicModelListRequest() async throws {
        let session = StubProtocol.session { _ in (200, [:], Data(#"{"data":[{"id":"claude-sonnet-5-5","type":"model"}],"has_more":false}"#.utf8)) }
        #expect(try await LLMClient(provider: anthropic, apiKey: "k", session: session).listModels() == ["claude-sonnet-5-5"])
        let request = StubProtocol.requests[0]
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/models?limit=1000")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    }

    @Test func summarizeMapReducesLongTranscripts() async throws {
        let session = StubProtocol.session { request in
            let system = json(request)?["system"] as? String ?? ""
            let text = system.hasPrefix("Condense")
                ? "notes"
                : "**SUMMARY:** They planned the launch.\nACTION ITEMS:\n1. Ana: send the deck\nSPEAKERS:\n- Ana: Owns the deck.\n- Ben: Asked about dates."
            let body = try JSONSerialization.data(withJSONObject: ["content": [["type": "text", "text": text]]])
            return (200, [:], body)
        }
        let transcript = (1...40).map { "\($0.isMultiple(of: 2) ? "Ana" : "Ben"): line number \($0) about the launch." }
            .joined(separator: "\n")
        let summary = try await Tasks.summarize(transcript: transcript,
                                                client: LLMClient(provider: anthropic, apiKey: "k", session: session),
                                                model: "m", maxCharacters: 300)
        let chunkCount = Tasks.chunks(transcript, maxCharacters: 300).count
        #expect(chunkCount > 1)
        #expect(StubProtocol.requests.count == chunkCount + 1)
        let final = json(StubProtocol.requests.last!)
        #expect((final?["system"] as? String)?.contains("each of: Ben, Ana") == true)
        #expect(summary == TranscriptSummary(
            text: "They planned the launch.",
            actionItems: ["Ana: send the deck"],
            speakers: [SpeakerNote(name: "Ana", points: "Owns the deck."), SpeakerNote(name: "Ben", points: "Asked about dates.")]
        ))
    }
}

// MARK: - Chunking and parsing

@Test func chunksFitAndKeepLinesWhole() {
    let lines = (1...50).map { "Speaker \($0 % 3): sentence number \($0) is here." }
    let chunks = Tasks.chunks(lines.joined(separator: "\n"), maxCharacters: 200)
    #expect(chunks.count > 1)
    #expect(chunks.allSatisfy { $0.count <= 200 })
    #expect(chunks.flatMap { $0.components(separatedBy: "\n") } == lines)
}

@Test func chunksHardSplitUnpunctuatedText() {
    let text = String(repeating: "word ", count: 500)
    let chunks = Tasks.chunks(text, maxCharacters: 100)
    #expect(chunks.allSatisfy { $0.count <= 100 })
    #expect(chunks.joined().filter { $0 != " " && $0 != "\n" } == text.filter { $0 != " " })
    #expect(Tasks.chunks("Short.", maxCharacters: 100) == ["Short."])
    #expect(Tasks.chunks("  \n ", maxCharacters: 100).isEmpty)
}

@Test func detectsSpeakers() {
    #expect(Tasks.speakers(in: "Alice: Hi.\nBob Smith: Hello.\nAlice: Shall we start?") == ["Alice", "Bob Smith"])
    #expect(Tasks.speakers(in: "[00:01] Alice: Hi.\n[00:04] Bob: Hey.") == ["Alice", "Bob"])
    #expect(Tasks.speakers(in: "We met today.\nIt went well.\nNote: buy milk.\nThe end.").isEmpty)
    #expect(Tasks.speakers(in: "Alice: only one line").isEmpty)
}

@Test func parsesSummaryReplies() {
    let summary = Tasks.parse("SUMMARY: Short call.\nACTION ITEMS:\n- None")
    #expect(summary == TranscriptSummary(text: "Short call.", actionItems: []))
    #expect(Tasks.parse("SUMMARY:\nTwo\nlines.\nACTION ITEMS: - [ ] Call Bo").text == "Two lines.")
    #expect(Tasks.summaryInstructions(speakers: []).contains("SPEAKERS") == false)
}

// MARK: - Settings

@Test func settingsRoundTrip() throws {
    let suite = "AIKitTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    var settings = AISettings.load(defaults)
    #expect(AITask.allCases.allSatisfy { settings[$0] == .onDevice })
    settings[.summaries] = .provider(id: "anthropic", model: "claude-sonnet-5-5")
    settings[.cleanup] = .provider(id: "groq", model: "llama-3.3-70b-versatile")
    settings.save(defaults)

    let loaded = AISettings.load(defaults)
    #expect(loaded == settings)
    #expect(loaded[.general] == .onDevice)
    #expect(defaults.data(forKey: "AIKit.settings") != nil)
    #expect(Tasks.route(.general, loaded) == nil)
    #expect(Tasks.route(.summaries, loaded)?.1 == "claude-sonnet-5-5")
}

@Test func onDeviceSummaryReturnsNilWithoutNetwork() async throws {
    #expect(try await Tasks.summarize(transcript: "Alice: hi", settings: AISettings()) == nil)
}
