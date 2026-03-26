import Foundation
import CryptoKit

// MARK: - Structured Proxy Request Bodies

/// Request body for POST /api/generate — server builds prompt + handles cache.
struct ProxyGenerateRequest: Encodable, Sendable {
    let provider:        String
    let model:           String
    let skillName:       String
    let category:        String
    let difficulty:      Int
    let healthScore:     Double
    let language:        String
    let count:           Int
    let recentQuestions: [String]?
}

/// Request body for POST /api/evaluate — server builds eval prompt.
struct ProxyEvaluateRequest: Encodable, Sendable {
    let provider:      String
    let model:         String
    let challengeType: String
    let question:      String
    let correctAnswer: String
    let explanation:   String
    let skillContext:  String
    let userAnswer:    String
    let language:      String
}

/// Request body for POST /api/breadth — server builds breadth-analysis prompt.
struct ProxyBreadthRequest: Encodable, Sendable {
    let provider:  String
    let model:     String
    let skillName: String
    let context:   String
    let category:  String
    let language:  String
}

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
    private let appSecret = "689c56112204cb20c351881782fcd001901822eccfd4d5ae9010de51922d5628"

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

    // MARK: - Structured Endpoints

    /// Sends skill data to POST /api/generate.
    /// The server builds the prompt, checks the TTL cache, and calls the AI provider.
    func generate(
        provider:        AIProvider,
        model:           String,
        skillName:       String,
        category:        String,
        difficulty:      Int,
        healthScore:     Double,
        language:        String,
        count:           Int,
        recentQuestions: [String]
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw APIError.networkUnavailable
        }
        let body = ProxyGenerateRequest(
            provider:        provider.rawValue,
            model:           model,
            skillName:       skillName,
            category:        category,
            difficulty:      difficulty,
            healthScore:     healthScore,
            language:        language,
            count:           count,
            recentQuestions: recentQuestions.isEmpty ? nil : recentQuestions
        )
        return try await performSignedRequest(url: url, body: body)
    }

    /// Sends evaluation data to POST /api/evaluate.
    func evaluate(
        provider:      AIProvider,
        model:         String,
        challengeType: String,
        question:      String,
        correctAnswer: String,
        explanation:   String,
        skillContext:  String,
        userAnswer:    String,
        language:      String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/evaluate") else {
            throw APIError.networkUnavailable
        }
        let body = ProxyEvaluateRequest(
            provider:      provider.rawValue,
            model:         model,
            challengeType: challengeType,
            question:      question,
            correctAnswer: correctAnswer,
            explanation:   explanation,
            skillContext:  skillContext,
            userAnswer:    userAnswer,
            language:      language
        )
        return try await performSignedRequest(url: url, body: body)
    }

    /// Sends skill breadth analysis request to POST /api/breadth.
    func analyzeBreadth(
        provider:  AIProvider,
        model:     String,
        skillName: String,
        context:   String,
        category:  String,
        language:  String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/breadth") else {
            throw APIError.networkUnavailable
        }
        let body = ProxyBreadthRequest(
            provider:  provider.rawValue,
            model:     model,
            skillName: skillName,
            context:   context,
            category:  category,
            language:  language
        )
        return try await performSignedRequest(url: url, body: body)
    }

    /// Shared helper: encodes `body`, signs it, executes request, returns `content` string.
    private func performSignedRequest<T: Encodable>(url: URL, body: T) async throws -> String {
        let isProUser  = await MainActor.run { SubscriptionService.shared.isPro }
        let bodyData   = try JSONEncoder().encode(body)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""

        var request        = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.httpBody   = bodyData
        request.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        request.setValue(sign(bodyString),          forHTTPHeaderField: "X-App-Signature")
        request.setValue(deviceID,                  forHTTPHeaderField: "X-Device-ID")
        request.setValue(isProUser ? "1" : "0",     forHTTPHeaderField: "X-Is-Pro")

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
            struct ContentResponse: Decodable { let content: String }
            guard let parsed = try? JSONDecoder().decode(ContentResponse.self, from: data) else {
                throw APIError.emptyResponse
            }
            return parsed.content
        case 401:
            throw APIError.missingAPIKey
        case 429:
            let retryAfter = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "3600") ?? 3600
            throw APIError.rateLimited(retryAfter: retryAfter)
        case 502, 503, 504:
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
