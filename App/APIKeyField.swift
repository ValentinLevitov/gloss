import SwiftUI
import UIKit

/// Key entry for one provider: where to get the key, paste, and an immediate check that the key works.
struct APIKeyField: View {
    let provider: ProviderKind
    /// Called after a key was verified (models loaded) or removed.
    var onChange: (_ hasKey: Bool) -> Void = { _ in }

    enum Status: Equatable { case none, checking, ok(Int), failed(String) }

    @State private var key: String
    @State private var status: Status
    @State private var verifyTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    init(provider: ProviderKind, onChange: @escaping (_ hasKey: Bool) -> Void = { _ in }) {
        self.provider = provider
        self.onChange = onChange
        let stored = KeychainStore.apiKey(for: provider) ?? ""
        _key = State(initialValue: stored)
        _status = State(initialValue: stored.isEmpty ? .none
                        : ModelCatalog.cached(for: provider).map { .ok($0.count) } ?? .none)
    }

    private var trimmed: String { key.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HStack {
            SecureField(provider.keyPlaceholder, text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .onSubmit { scheduleVerify(delay: 0) }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused, trimmed != KeychainStore.apiKey(for: provider) ?? "" { scheduleVerify(delay: 0) }
                }
                // Verify as the user types or pastes, without waiting for Return or focus to move.
                .onChange(of: key) { _, _ in
                    guard trimmed != KeychainStore.apiKey(for: provider) ?? "" || status == .none else { return }
                    if trimmed.isEmpty { status = .none }
                    scheduleVerify(delay: 600)
                }

            switch status {
            case .checking:
                ProgressView().controlSize(.small)
            case .ok:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .none:
                EmptyView()
            }

            if trimmed.isEmpty {
                PasteButton(payloadType: String.self) { strings in
                    if let pasted = strings.first { key = pasted; scheduleVerify(delay: 0) }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .controlSize(.small)
            } else {
                Button { key = ""; scheduleVerify(delay: 0) } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }

        Link(destination: provider.consoleURL) {
            Label("Get a key at \(provider.consoleURL.host() ?? "")", systemImage: "arrow.up.right.square")
                .font(.footnote)
        }

        switch status {
        case .failed(let message):
            HStack {
                Text(message).font(.footnote).foregroundStyle(.red)
                Spacer()
                Button("Retry") { scheduleVerify(delay: 0) }.font(.footnote)
            }
        case .ok(let count):
            Text("Key works · \(count) models available").font(.footnote).foregroundStyle(.secondary)
        case .checking:
            Text("Checking the key…").font(.footnote).foregroundStyle(.secondary)
        case .none:
            if !trimmed.isEmpty {
                Button("Verify key") { scheduleVerify(delay: 0) }.font(.footnote)
            }
        }
    }

    /// Single entry point for every trigger, so a paste followed by the debounce (or Return) verifies once.
    private func scheduleVerify(delay: Int) {
        verifyTask?.cancel()
        verifyTask = Task {
            if delay > 0 { try? await Task.sleep(for: .milliseconds(delay)) }
            guard !Task.isCancelled else { return }
            await verify()
        }
    }

    @MainActor
    private func verify() async {
        guard KeychainStore.setAPIKey(trimmed, for: provider) else {
            status = .failed(String(localized: "Couldn't save the key to Keychain"))
            return
        }
        guard !trimmed.isEmpty else {
            status = .none
            onChange(false)
            return
        }
        status = .checking
        do {
            let models = try await ModelCatalog.refresh(provider)
            status = .ok(models.count)
            onChange(true)
        } catch {
            status = .failed(error.localizedDescription)
            onChange(false)
        }
    }
}
