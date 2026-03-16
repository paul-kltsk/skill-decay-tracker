import Foundation

// MARK: - API Error

/// Errors produced by ``ClaudeAPIClient`` and ``AIService``.
///
/// All cases are `Sendable` — safe to propagate across actor boundaries.
enum APIError: Error, LocalizedError, Sendable {

    /// The Claude API key is absent from Keychain or is empty.
    case missingAPIKey

    /// The server returned HTTP 429. `retryAfter` is the suggested wait in seconds.
    case rateLimited(retryAfter: TimeInterval)

    /// The server returned a non-2xx status code.
    case httpError(statusCode: Int, body: String)

    /// The server response could not be decoded into the expected type.
    case decodingFailed(underlying: any Error)

    /// The response body was present but contained no usable content.
    case emptyResponse

    /// Claude returned text that could not be parsed as valid JSON.
    case invalidJSON(raw: String)

    /// A network-level error (no connection, timeout, etc.).
    case networkUnavailable

    // MARK: LocalizedError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return String(localized: "Claude API key not set. Add it in Settings.")
        case .rateLimited(let after):
            return String(localized: "Too many requests. Please wait \(Int(after)) seconds.")
        case .httpError(let code, _):
            return String(localized: "Server error (HTTP \(code)). Please try again.")
        case .decodingFailed:
            return String(localized: "Unexpected response format from the AI service.")
        case .emptyResponse:
            return String(localized: "The AI returned an empty response.")
        case .invalidJSON(let raw):
            return String(localized: "Could not parse AI response as JSON: \(raw.prefix(80))")
        case .networkUnavailable:
            return String(localized: "No network connection. Using offline challenges.")
        }
    }

    /// `true` when the error is recoverable by showing fallback content instead of a hard failure.
    var allowsFallback: Bool {
        switch self {
        case .missingAPIKey, .rateLimited, .httpError, .networkUnavailable: return true
        case .decodingFailed, .emptyResponse, .invalidJSON:                   return false
        }
    }
}
