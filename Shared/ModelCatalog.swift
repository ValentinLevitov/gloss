import Foundation

/// Model lists fetched from each provider, cached in the App Group so they survive restarts
/// and are shared with the extensions.
enum ModelCatalog {
    private static let maxAge: TimeInterval = 24 * 60 * 60

    private static func cacheKey(_ provider: ProviderKind) -> String { "modelCatalog.\(provider.rawValue)" }
    private static func fetchedAtKey(_ provider: ProviderKind) -> String { "modelCatalogFetchedAt.\(provider.rawValue)" }

    static func cached(for provider: ProviderKind) -> [ModelOption]? {
        guard let data = AppGroup.defaults.data(forKey: cacheKey(provider)),
              let models = try? JSONDecoder().decode([ModelOption].self, from: data),
              !models.isEmpty else { return nil }
        return models
    }

    static func models(for provider: ProviderKind) -> [ModelOption] {
        cached(for: provider) ?? ModelOption.builtIn(for: provider)
    }

    static func isStale(_ provider: ProviderKind) -> Bool {
        let fetchedAt = AppGroup.defaults.object(forKey: fetchedAtKey(provider)) as? Date ?? .distantPast
        return Date().timeIntervalSince(fetchedAt) > maxAge
    }

    /// Fetches the list and updates the cache. Errors are returned so Settings can show them; callers that
    /// refresh in the background just ignore them.
    @discardableResult
    static func refresh(_ provider: ProviderKind) async throws -> [ModelOption] {
        let models = try await Providers.make(for: provider).listModels()
        guard !models.isEmpty else { return self.models(for: provider) }
        if let data = try? JSONEncoder().encode(models) {
            AppGroup.defaults.set(data, forKey: cacheKey(provider))
            AppGroup.defaults.set(Date(), forKey: fetchedAtKey(provider))
        }
        return models
    }

    static func refreshStale() {
        for provider in ProviderKind.allCases where provider.hasKey && isStale(provider) {
            Task { try? await refresh(provider) }
        }
    }
}
