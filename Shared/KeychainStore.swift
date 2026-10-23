import Foundation
import Security

enum AppGroup {
    static let id = "group.com.vlevitov.translator"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }

    /// A shared data file. Files sit in `Library/` of the group container, which is where tools like
    /// `devicectl` can read them from a development build; files from 1.1 at the container root are moved there.
    static func fileURL(_ name: String) -> URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let library = container.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        let url = library.appendingPathComponent(name)
        let legacy = container.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: url)
        }
        return url
    }
}

/// API keys live in the Keychain under the App Group access group so both the app and the extensions can read them.
enum KeychainStore {
    private static let service = "com.vlevitov.translator.apikey"

    private static func baseQuery(_ provider: ProviderKind) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecAttrAccessGroup as String: AppGroup.id,
        ]
    }

    static func apiKey(for provider: ProviderKind) -> String? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func setAPIKey(_ key: String, for provider: ProviderKind) -> Bool {
        SecItemDelete(baseQuery(provider) as CFDictionary)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        var query = baseQuery(provider)
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}
