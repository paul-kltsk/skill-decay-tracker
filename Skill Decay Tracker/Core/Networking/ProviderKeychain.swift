import Foundation
import Security

// MARK: - ProviderKeychain

/// Generic Keychain storage for AI provider API keys.
///
/// All keys share the same Keychain service identifier
/// (`"pavel.kulitski.Skill-Decay-Tracker"`) and are distinguished
/// by per-provider account names (`"claude-api-key"`, `"openai-api-key"`, …).
///
/// The Claude account name (`"claude-api-key"`) intentionally matches the one
/// used by the legacy `ClaudeAPIClient` Keychain methods, so existing stored
/// keys are transparently readable by both paths.
enum ProviderKeychain {

    private static let service = "pavel.kulitski.Skill-Decay-Tracker"

    private static func account(for provider: AIProvider) -> String {
        "\(provider.rawValue)-api-key"
    }

    // MARK: - Store

    /// Stores (or replaces) the API key for `provider` in the device Keychain.
    ///
    /// - Returns: `true` on success, `false` if the Keychain write failed.
    @discardableResult
    static func store(_ key: String, for provider: AIProvider) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        // Delete existing item first (ignore status — may not exist)
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account(for: provider),
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Read

    /// Reads the stored API key for `provider`.
    ///
    /// - Throws: `APIError.missingAPIKey` when no key is found.
    static func read(for provider: AIProvider) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let key  = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            throw APIError.missingAPIKey
        }
        return key
    }

    // MARK: - Delete

    /// Removes the stored API key for `provider` from the Keychain.
    static func delete(for provider: AIProvider) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Has

    /// Returns `true` if an API key for `provider` is currently in the Keychain.
    static func has(for provider: AIProvider) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}
