import AIKit
import SwiftUI

/// Settings screen: connect providers with your own keys, then choose what
/// each task uses. Everything defaults to on-device.
public struct AIProvidersView: View {
    private let defaults: UserDefaults
    @State private var settings: AISettings
    @State private var connected: Set<String> = []
    @State private var models: [String: [String]] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _settings = State(initialValue: AISettings.load(defaults))
    }

    public var body: some View {
        Form {
            Section {
                ForEach(AITask.allCases) { task in
                    TaskRow(task: task, engine: $settings[task], providers: choices(for: settings[task]),
                            models: models[providerID(settings[task]) ?? ""] ?? [])
                        .task(id: providerID(settings[task])) { await loadModels(providerID(settings[task])) }
                }
            } header: {
                Text("Use for")
            } footer: {
                Label("On-device keeps everything on this Mac. With a cloud provider, the text of the transcript "
                      + "or note is sent to that provider under its terms; audio is never sent. "
                      + "Keys are stored in your Keychain.", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Providers") {
                ForEach(Provider.all) { provider in
                    ProviderRow(provider: provider, isConnected: connected.contains(provider.id),
                                onKeyChange: refresh, onModels: { models[provider.id] = $0 })
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onChange(of: settings) { _, new in new.save(defaults) }
    }

    private func refresh() {
        connected = Set(Provider.all.filter { !$0.needsKey || KeychainStore.contains($0.id) }.map(\.id))
    }

    /// Connected providers, plus the current pick even if its key was removed,
    /// so the picker always has a matching tag.
    private func choices(for engine: AIEngine) -> [Provider] {
        Provider.all.filter { connected.contains($0.id) || $0.id == providerID(engine) }
    }

    private func providerID(_ engine: AIEngine) -> String? {
        if case .provider(let id, _) = engine { return id }
        return nil
    }

    private func loadModels(_ id: String?) async {
        guard let id, models[id] == nil, let provider = Provider.named(id) else { return }
        if let list = try? await LLMClient(provider: provider).listModels() { models[id] = list }
    }
}

private struct TaskRow: View {
    let task: AITask
    @Binding var engine: AIEngine
    let providers: [Provider]
    let models: [String]

    var body: some View {
        Picker(task.title, selection: providerID) {
            Text("On-device (private)").tag("")
            ForEach(providers) { Text($0.name).tag($0.id) }
        }
        if case .provider = engine {
            LabeledContent("Model") {
                HStack(spacing: 4) {
                    // Free text so any model works, even one the list filters out.
                    TextField("Model ID", text: model).labelsHidden().multilineTextAlignment(.trailing)
                    if !models.isEmpty {
                        Menu {
                            ForEach(models, id: \.self) { id in Button(id) { model.wrappedValue = id } }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    }
                }
            }
            .padding(.leading, 12)
        }
    }

    private var providerID: Binding<String> {
        Binding {
            if case .provider(let id, _) = engine { return id }
            return ""
        } set: { id in
            engine = Provider.named(id).map { .provider(id: $0.id, model: $0.defaultModel) } ?? .onDevice
        }
    }

    private var model: Binding<String> {
        Binding {
            if case .provider(_, let model) = engine { return model }
            return ""
        } set: { model in
            if case .provider(let id, _) = engine { engine = .provider(id: id, model: model) }
        }
    }
}

private struct ProviderRow: View {
    let provider: Provider
    let isConnected: Bool
    let onKeyChange: () -> Void
    let onModels: ([String]) -> Void
    @State private var draft = ""
    @State private var result: (text: String, ok: Bool)?
    @State private var testing = false

    var body: some View {
        DisclosureGroup {
            if provider.needsKey {
                HStack {
                    SecureField("Paste API key", text: $draft).textFieldStyle(.roundedBorder).labelsHidden()
                    Button("Save", action: save).disabled(trimmedDraft.isEmpty)
                }
            }
            HStack {
                Button("Test") { Task { await test() } }
                    .disabled(testing || (provider.needsKey && !isConnected))
                if provider.needsKey && isConnected {
                    Button("Remove Key", role: .destructive) {
                        KeychainStore.delete(provider.id)
                        result = nil
                        onKeyChange()
                    }
                }
                if testing { ProgressView().controlSize(.small) }
                if let result {
                    Text(result.text).font(.caption).lineLimit(2)
                        .foregroundStyle(result.ok ? Color.green : Color.red)
                }
                Spacer()
                Link(provider.needsKey ? "Get a key" : "Get Ollama", destination: provider.keyURL).font(.caption)
            }
            .controlSize(.small)
        } label: {
            HStack {
                Text(provider.name)
                Spacer()
                if !provider.needsKey {
                    Text("Local, no key").foregroundStyle(.secondary)
                } else if isConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Text("Not connected").foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
    }

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        do {
            try KeychainStore.save(trimmedDraft, for: provider.id)
            draft = ""
            onKeyChange()
            Task { await test() }
        } catch {
            result = (error.localizedDescription, false)
        }
    }

    /// Listing models proves the key works without spending tokens or
    /// sending any content.
    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let models = try await LLMClient(provider: provider).listModels()
            onModels(models)
            result = ("Works, \(models.count) models", true)
        } catch {
            result = (error.localizedDescription, false)
        }
    }
}
