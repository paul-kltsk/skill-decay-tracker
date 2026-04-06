import Foundation
import Security

// MARK: - HTTP Session Protocol

/// Abstracts `URLSession` for dependency injection in tests.
protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {}

// MARK: - Request / Response Types

/// Outgoing body for `POST /v1/messages`.
private struct MessagesRequest: Sendable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [MessageDTO]
}
nonisolated extension MessagesRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

/// A single turn in the conversation sent to Claude.
struct MessageDTO: Sendable {
    let role: String   // "user" | "assistant"
    let content: String
}
nonisolated extension MessageDTO: Encodable {}

/// Top-level response body returned by `POST /v1/messages`.
private struct MessagesResponse: Sendable {
    let content: [ContentBlock]

    struct ContentBlock: Sendable {
        let type: String
        let text: String
    }
}
nonisolated extension MessagesResponse: Decodable {}
nonisolated extension MessagesResponse.ContentBlock: Decodable {}

// MARK: - Claude API Client

/// Low-level actor wrapping the Claude Messages API.
///
/// Responsibilities:
/// - Rate-limiting (≥ 3 s between requests)
/// - Exponential back-off on HTTP 429 (up to 4 retries)
/// - Reading / writing the API key via Keychain
///
/// Consumers should use ``AIService`` instead of calling this directly.
actor ClaudeAPIClient {

    // MARK: Singleton

    /// Shared client using the live `URLSession`.
    static let shared = ClaudeAPIClient()

    // MARK: Configuration

    private let session: any HTTPSession
    // Compile-time constant — safe to force-unwrap (validated static literal).
    private let baseURL: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let anthropicVersion = "2023-06-01"

    /// Minimum gap between outgoing requests.
    private let minRequestInterval: TimeInterval = 3.0

    // MARK: Rate-limit state

    private var lastRequestDate: Date = .distantPast

    // MARK: Init

    init(session: any HTTPSession = URLSession.shared) {
        self.session = session
    }

    // MARK: - Send

    /// Sends a single-turn prompt to Claude and returns the assistant's text.
    ///
    /// - Parameters:
    ///   - model: Model ID, e.g. `"claude-sonnet-4-20250514"`.
    ///   - maxTokens: Maximum tokens in the reply.
    ///   - systemPrompt: Optional system-level instruction (injected as top-level `system` field).
    ///   - prompt: The user-turn text.
    /// - Returns: The assistant's raw text reply.
    /// - Throws: ``APIError``
    func send(model: String, maxTokens: Int, systemPrompt: String = "", prompt: String) async throws -> String {
        // Enforce minimum interval
        let elapsed = Date.now.timeIntervalSince(lastRequestDate)
        if elapsed < minRequestInterval {
            try await Task.sleep(for: .seconds(minRequestInterval - elapsed))
        }

        let apiKey = try readAPIKey()

        let body = MessagesRequest(
            model: model,
            maxTokens: maxTokens,
            system: systemPrompt.isEmpty ? nil : systemPrompt,
            messages: [MessageDTO(role: "user", content: prompt)]
        )
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion,   forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        return try await execute(request: request, attempt: 0)
    }

    // MARK: - Retry Logic

    private func execute(request: URLRequest, attempt: Int) async throws -> String {
        lastRequestDate = Date.now

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkUnavailable
        }

        switch http.statusCode {
        case 200...299:
            return try decodeText(from: data)

        case 401:
            throw APIError.invalidAPIKey(provider: .claude)

        case 402:
            throw APIError.insufficientCredits(provider: .claude)

        case 429:
            guard attempt < 4 else {
                throw APIError.rateLimited(retryAfter: 60)
            }
            let suggested = Double(http.value(forHTTPHeaderField: "retry-after") ?? "") ?? 0
            let delay = max(suggested, pow(2.0, Double(attempt)) * minRequestInterval)
            try await Task.sleep(for: .seconds(delay))
            return try await execute(request: request, attempt: attempt + 1)

        case 529:
            // Anthropic service overloaded — treat as transient network issue
            throw APIError.networkUnavailable

        default:
            let body = String(decoding: data, as: UTF8.self)
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    // MARK: - Decoding

    private func decodeText(from data: Data) throws -> String {
        do {
            let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
            guard let block = decoded.content.first(where: { $0.type == "text" }) else {
                throw APIError.emptyResponse
            }
            return block.text
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Keychain

    private static let keychainService = "pavel.kulitski.Skill-Decay-Tracker"
    private static let keychainAccount = "claude-api-key"

    /// Reads the API key from Keychain.
    private func readAPIKey() throws -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: Self.keychainAccount,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            throw APIError.missingAPIKey
        }
        return key
    }

    /// Persists the API key in Keychain, replacing any previous value.
    ///
    /// Call this from Settings when the user enters their key.
    @discardableResult
    static func storeAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        // Delete old entry first (ignore status — may not exist yet)
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    keychainService,
            kSecAttrAccount:    keychainAccount,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// Removes the stored API key from Keychain.
    static func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Returns `true` if an API key is currently stored in Keychain.
    static func hasAPIKey() -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}
