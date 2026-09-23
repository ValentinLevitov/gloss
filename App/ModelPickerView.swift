import SwiftUI

/// One section per provider: its API key and the models the key can use.
struct ModelPickerView: View {
    @Binding var selected: ModelOption
    @State private var expanded: Set<ProviderKind> = []

    var body: some View {
        List {
            ForEach(ProviderKind.allCases) { provider in
                ProviderSection(provider: provider, selected: $selected,
                                showAll: expanded.contains(provider)) { expanded.insert(provider) }
            }
        }
        .navigationTitle("Model")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProviderSection: View {
    let provider: ProviderKind
    @Binding var selected: ModelOption
    let showAll: Bool
    let onShowAll: () -> Void

    private static let collapsedCount = 4

    @State private var hasKey: Bool
    @State private var models: [ModelOption]
    @State private var error: String?
    @State private var isRefreshing = false

    init(provider: ProviderKind, selected: Binding<ModelOption>, showAll: Bool, onShowAll: @escaping () -> Void) {
        self.provider = provider
        self._selected = selected
        self.showAll = showAll
        self.onShowAll = onShowAll
        _hasKey = State(initialValue: provider.hasKey)
        _models = State(initialValue: ModelCatalog.models(for: provider))
    }

    private var visibleModels: [ModelOption] {
        if showAll || models.count <= Self.collapsedCount { return models }
        // Keep the selected model visible even when it is further down the list.
        var top = Array(models.prefix(Self.collapsedCount))
        if selected.provider == provider, !top.contains(selected), let current = models.first(where: { $0 == selected }) {
            top.append(current)
        }
        return top
    }

    var body: some View {
        Section {
            APIKeyField(provider: provider) { ok in
                hasKey = ok
                if ok {
                    models = ModelCatalog.models(for: provider)
                    if selected.provider == provider, !models.contains(selected), let first = models.first {
                        selected = first
                    }
                } else if selected.provider == provider,
                          let fallback = ProviderKind.allCases.first(where: \.hasKey) {
                    selected = ModelCatalog.models(for: fallback).first ?? .default
                }
            }

            if hasKey {
                ForEach(visibleModels) { model in
                    Button {
                        selected = model
                    } label: {
                        HStack {
                            Text(model.title)
                            Spacer()
                            if model == selected { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                        }
                    }
                    .tint(.primary)
                }
                if !showAll, models.count > Self.collapsedCount {
                    Button("Show all \(models.count)", action: onShowAll)
                        .font(.footnote)
                }
            }
        } header: {
            HStack {
                Text(provider.title)
                Spacer()
                if isRefreshing {
                    ProgressView().controlSize(.mini)
                } else if hasKey {
                    Button("Refresh") { Task { await refresh() } }
                        .font(.footnote)
                        .textCase(nil)
                }
            }
        } footer: {
            if let error { Text(error).foregroundStyle(.red) }
        }
        .task {
            if hasKey, ModelCatalog.isStale(provider) { await refresh() }
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            models = try await ModelCatalog.refresh(provider)
            error = nil
            if selected.provider == provider, !models.contains(selected), let first = models.first {
                selected = first
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
