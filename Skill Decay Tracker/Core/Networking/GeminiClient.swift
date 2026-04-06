import Foundation

// MARK: - Gemini Client

/// Low-level actor wrapping the Google Gemini `generateContent` API.
///
/// Reads the API key from `ProviderKeychain` on every call.
/// The key is passed as a query parameter (Google's standard auth method).
///
/// Consumers should use ``AIService`` rather than calling this directly.
actor GeminiClient {

    // MARK: Singleton

    static let shared = GeminiClient()

    // MARK: Configuration

    private let session: any HTTPSession
    private let baseHost = "https://generativelanguage.googleapis.com/v1beta/models"
    private let minRequestInterval: TimeInterval = 1.0

    private var lastRequestDate: Date = .distantPast

    // MARK: Init

    init(session: any HTTPSession = URLSession.shared) {
        self.session = session
    }

    // MARK: - Send

    /// Sends a single-turn prompt to Gemini and returns the model's text.
    ///
    /// - Parameters:
    ///   - model: Model ID, e.g. `"gemini-2.0-flash"`.
    ///   - maxTokens: Maximum tokens in the reply.
    ///   - prompt: The user-turn text.
    /// - Throws: ``APIError``
    func send(model: String, maxTokens: Int, prompt: String) async throws -> String {
        // Rate-limit
        let elapsed = Date.now.timeIntervalSince(lastRequestDate)
        if elapsed < minRequestInterval {
            try await Task.sleep(for: .seconds(minRequestInterval - elapsed))
        }

        let apiKey = try ProviderKeychain.read(for: .gemini)

        // Build URL: .../models/{model}:generateContent?key={KEY}
        guard var components = URLComponents(string: "\(baseHost)/\(model):generateContent") else {
            throw APIError.networkUnavailable
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw APIError.networkUnavailable }

        let body = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: prompt)])],
            generationConfig: GeminiConfig(maxOutputTokens: maxTokens)
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        lastRequestDate = Date.now
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkUnavailable
        }

        if !(200...299).contains(http.statusCode) {
            let body = String(decoding: data, as: UTF8.self)
            switch http.statusCode {
            case 400:
                // Gemini returns HTTP 400 with API_KEY_INVALID for bad keys
                if body.contains("API_KEY_INVALID") {
                    throw APIError.invalidAPIKey(provider: .gemini)
                }
                throw APIError.httpError(statusCode: 400, body: body)
            case 403:
                throw APIError.invalidAPIKey(provider: .gemini)
            case 429:
                throw APIError.rateLimited(retryAfter: 60)
            default:
                throw APIError.httpError(statusCode: http.statusCode, body: body)
            }
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw APIError.emptyResponse
        }
        return text
    }
}

// MARK: - Request / Response Types

private struct GeminiRequest: Sendable {
    let contents: [GeminiContent]
    let generationConfig: GeminiConfig
}
nonisolated extension GeminiRequest: Encodable {}

private struct GeminiContent: Sendable {
    let parts: [GeminiPart]
}
nonisolated extension GeminiContent: Encodable {}

private struct GeminiPart: Sendable {
    let text: String
}
nonisolated extension GeminiPart: Encodable {}

private struct GeminiConfig: Sendable {
    let maxOutputTokens: Int
    let temperature: Double = 0.7
}
nonisolated extension GeminiConfig: Encodable {}

private struct GeminiResponse: Sendable {
    let candidates: [Candidate]

    struct Candidate: Sendable {
        let content: ResponseContent
    }
    struct ResponseContent: Sendable {
        let parts: [GeminiPart]
    }
    struct GeminiPart: Sendable {
        let text: String
    }
}
nonisolated extension GeminiResponse: Decodable {}
nonisolated extension GeminiResponse.Candidate: Decodable {}
nonisolated extension GeminiResponse.ResponseContent: Decodable {}
nonisolated extension GeminiResponse.GeminiPart: Decodable {}
