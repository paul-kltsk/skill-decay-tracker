import Foundation
import CryptoKit

// MARK: - Proxy API Client

/// Sends AI prompts through the SDT proxy server at `sdtapi.mooo.com`.
///
/// Used automatically by ``AIService`` when the user has not added a personal
/// API key for the selected provider — requires no configuration from the user.
///
/// **Security model:**
/// Every request is signed with HMAC-SHA256 using `appSecret` (shared with the
/// server via `.env`). The server rejects unsigned requests with HTTP 401.
/// Per-device rate limits are enforced server-side by `X-Device-ID`.
actor ProxyAPIClient {

    // MARK: - Singleton

    static let shared = ProxyAPIClient()
    private init() {}

    // MARK: - Configuration

    /// Base URL of the proxy server.
    private let baseURL = "https://sdtapi.mooo.com"

    /// Shared HMAC secret — must exactly match `APP_SECRET` in the server's `.env`.
    ///
    /// ⚠️ Generate your own value with:
    ///   `openssl rand -hex 32`
    /// Then paste the same string here AND in the server `.env` file.
    private let appSecret = "REPLACE_WITH_YOUR_32_CHAR_SECRET"

    // MARK: - Stable Device ID

    /// Persisted per-device identifier used for server-side rate limiting.
    /// Stored in UserDefaults so it survives app updates but resets on reinstall.
    private let deviceID: String = {
        let key = "com.sdt.proxyDeviceID"
        if let stored = UserDefaults.standard.string(forKey: key) { return stored }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }()

    // MARK: - Send

    /// Forwards a prompt to the proxy server and returns the AI text response.
    ///
    /// - Parameters:
    ///   - provider: Which AI backend the server should use.
    ///   - model: Model ID string (e.g. `"claude-haiku-4-5-20251001"`).
    ///   - maxTokens: Token budget for the response (capped at 4096 by the server).
    ///   - prompt: The full user-turn prompt to forward.
    /// - Throws: ``APIError`` — mapped from HTTP status codes so ``AIService``
    ///           can apply the same fallback logic as with direct clients.
    func send(
        provider: AIProvider,
        model: String,
        maxTokens: Int,
        prompt: String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw APIError.networkUnavailable
        }

        // Build JSON body
        let bodyDict: [String: Any] = [
            "provider":  provider.rawValue,
            "model":     model,
            "maxTokens": maxTokens,
            "prompt":    prompt,
        ]
        let bodyData   = try JSONSerialization.data(withJSONObject: bodyDict)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""

        // Read Pro status on the main actor (SubscriptionService is @MainActor)
        let isProUser = await MainActor.run { SubscriptionService.shared.isPro }

        // Build signed URLRequest
        var request        = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.httpBody   = bodyData
        request.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        request.setValue(sign(bodyString),          forHTTPHeaderField: "X-App-Signature")
        request.setValue(deviceID,                  forHTTPHeaderField: "X-Device-ID")
        request.setValue(isProUser ? "1" : "0",     forHTTPHeaderField: "X-Is-Pro")

        // Execute request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkUnavailable
        }

        switch http.statusCode {
        case 200...299:
            struct ProxyResponse: Decodable { let content: String }
            guard let parsed = try? JSONDecoder().decode(ProxyResponse.self, from: data) else {
                throw APIError.emptyResponse
            }
            return parsed.content

        case 401:
            // Signature mismatch — app secret mismatch, treat as missing key
            throw APIError.missingAPIKey

        case 429:
            // Server-side rate limit hit
            let retryAfter = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "3600") ?? 3600
            throw APIError.rateLimited(retryAfter: retryAfter)

        case 502, 503, 504:
            // Upstream AI provider unavailable
            throw APIError.networkUnavailable

        default:
            throw APIError.httpError(statusCode: http.statusCode,
                                     body: String(data: data, encoding: .utf8) ?? "")
        }
    }

    // MARK: - HMAC-SHA256 Signing

    /// Returns the hex-encoded HMAC-SHA256 of `body` using `appSecret`.
    private func sign(_ body: String) -> String {
        let key = SymmetricKey(data: Data(appSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(body.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }
}
