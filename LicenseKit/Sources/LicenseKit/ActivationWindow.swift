import AppKit
import SwiftUI

extension License {
    /// Shows the activation window and waits until the app is unlocked (or the user
    /// quits). Call before creating anything that runs, such as hotkeys or the camera.
    @MainActor
    public static func requireActivation(appName: String) {
        guard !isUnlocked else {
            Task { await recheckIfDue() }
            return
        }
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.contentViewController = NSHostingController(rootView: ActivationView(appName: appName) {
            NSApp.stopModal()
        })
        panel.center()
        let app = NSApplication.shared // may run before the app has started
        let policy = app.activationPolicy()
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        // Closing the window without a key quits.
        if app.runModal(for: panel) != .stop { exit(0) }
        panel.close()
        app.setActivationPolicy(policy)
    }
}

struct ActivationView: View {
    let appName: String
    let done: () -> Void
    @State private var key = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 64, height: 64)
            VStack(spacing: 4) {
                Text("Activate \(appName)").font(.title3.weight(.semibold))
                Text("Paste the license key from your Gumroad receipt. One key unlocks every Humanity app.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX", text: $key)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .multilineTextAlignment(.center)
                .onSubmit(activate)
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Buy a License") { NSWorkspace.shared.open(License.buyURL) }
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button("Activate", action: activate)
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy || License.findKey(in: key) == nil)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            // Copied the key from the receipt? It's already filled in.
            if let copied = NSPasteboard.general.string(forType: .string).flatMap(License.findKey) { key = copied }
        }
    }

    private func activate() {
        guard let found = License.findKey(in: key), !busy else { return }
        busy = true
        error = nil
        Task {
            do {
                try await License.activate(found)
                done()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}
