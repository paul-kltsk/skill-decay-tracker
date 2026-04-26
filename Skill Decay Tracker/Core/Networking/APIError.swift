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

    /// HTTP 401 from a direct provider — key is invalid or has been revoked.
    case invalidAPIKey(provider: AIProvider)

    /// HTTP 402 or provider-specific quota error — the account has run out of credits.
    case insufficientCredits(provider: AIProvider)

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
            return String(localized: "API key not set. Add it in Settings → AI Model.")
        case .rateLimited(let after):
            return String(localized: "Too many requests. Please wait \(Int(after)) seconds.")
        case .invalidAPIKey:
            return String(localized: "API key is invalid or revoked. Update it in Settings → AI Model.")
        case .insufficientCredits:
            return String(localized: "Your AI account has run out of credits.")
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

    /// User-facing message with actionable guidance. Use this in UI error states.
    var userFacingMessage: String {
        switch self {
        case .invalidAPIKey(.claude):
            return String(localized: "Your Anthropic API key is invalid or has been revoked. Update it in Settings → AI Model.")
        case .invalidAPIKey(.openai):
            return String(localized: "Your OpenAI API key is invalid or has been revoked. Update it in Settings → AI Model.")
        case .invalidAPIKey(.gemini):
            return String(localized: "Your Gemini API key is invalid or has been revoked. Update it in Settings → AI Model.")
        case .insufficientCredits(.claude):
            return String(localized: "Your Anthropic account has run out of credits. Top up at console.anthropic.com to continue.")
        case .insufficientCredits(.openai):
            return String(localized: "Your OpenAI account has run out of credits. Top up at platform.openai.com/account/billing to continue.")
        case .insufficientCredits(.gemini):
            return String(localized: "Your Google AI account has reached its quota. Check aistudio.google.com to continue.")
        case .rateLimited(let after):
            return String(localized: "Too many requests. Please wait \(Int(after)) seconds and try again.")
        case .networkUnavailable:
            return String(localized: "No internet connection. Using offline challenges for now.")
        default:
            return errorDescription ?? String(localized: "Something went wrong. Please try again.")
        }
    }

    /// `true` when the error is recoverable by showing fallback content instead of a hard failure.
    var allowsFallback: Bool {
        switch self {
        case .missingAPIKey, .rateLimited, .httpError, .networkUnavailable,
             .invalidAPIKey, .insufficientCredits:
            return true
        case .decodingFailed, .emptyResponse, .invalidJSON:
            return false
        }
    }
}
