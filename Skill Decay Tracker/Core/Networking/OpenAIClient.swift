import Foundation

// MARK: - OpenAI Client

/// Low-level actor wrapping the OpenAI Chat Completions API.
///
/// Reads the API key from `ProviderKeychain` on every call so that
/// key changes in Settings are picked up immediately.
///
/// Consumers should use ``AIService`` rather than calling this directly.
actor OpenAIClient {

    // MARK: Singleton

    static let shared = OpenAIClient()

    // MARK: Configuration

    private let session: any HTTPSession
    // Compile-time constant — safe to force-unwrap (validated static literal).
    private let baseURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let minRequestInterval: TimeInterval = 1.0

    private var lastRequestDate: Date = .distantPast

    // MARK: Init

    init(session: any HTTPSession = URLSession.shared) {
        self.session = session
    }

    // MARK: - Send

    /// Sends a single-turn prompt to OpenAI and returns the assistant's text.
    ///
    /// - Parameters:
    ///   - model: Model ID, e.g. `"gpt-4o-mini"`.
    ///   - maxTokens: Maximum tokens in the reply.
    ///   - systemPrompt: Optional system-level instruction (prepended as `{"role":"system"}` message).
    ///   - prompt: The user-turn text.
    /// - Throws: ``APIError``
    func send(model: String, maxTokens: Int, systemPrompt: String = "", prompt: String) async throws -> String {
        // Rate-limit
        let elapsed = Date.now.timeIntervalSince(lastRequestDate)
        if elapsed < minRequestInterval {
            try await Task.sleep(for: .seconds(minRequestInterval - elapsed))
        }

        let apiKey = try ProviderKeychain.read(for: .openai)

        var messages = [OpenAIMessage]()
        if !systemPrompt.isEmpty {
            messages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }
        messages.append(OpenAIMessage(role: "user", content: prompt))

        let body = OpenAIRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens
        )
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
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
            case 401:
                throw APIError.invalidAPIKey(provider: .openai)
            case 429:
                // OpenAI returns insufficient_quota at 429, not 402
                if body.contains("insufficient_quota") {
                    throw APIError.insufficientCredits(provider: .openai)
                }
                throw APIError.rateLimited(retryAfter: 60)
            default:
                throw APIError.httpError(statusCode: http.statusCode, body: body)
            }
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw APIError.emptyResponse
        }
        return text
    }
}

// MARK: - Request / Response Types

private struct OpenAIRequest: Sendable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
}
nonisolated extension OpenAIRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Sendable {
    let role: String
    let content: String
}
nonisolated extension OpenAIMessage: Encodable {}

private struct OpenAIResponse: Sendable {
    let choices: [Choice]

    struct Choice: Sendable {
        let message: MessageContent
    }
    struct MessageContent: Sendable {
        let content: String
    }
}
nonisolated extension OpenAIResponse: Decodable {}
nonisolated extension OpenAIResponse.Choice: Decodable {}
nonisolated extension OpenAIResponse.MessageContent: Decodable {}
