import Foundation

// MARK: - AIModelTier

/// Quality tier for AI model selection when using a personal API key.
///
/// The tier controls which model is used for challenge generation.
/// Evaluation always uses the fast model regardless of tier to keep costs predictable.
///
/// Only applies to the own-key path. The proxy server manages its own model selection.
enum AIModelTier: String, CaseIterable, Codable, Sendable {

    /// Fast, cost-efficient model. Best for high-volume practice.
    case fast

    /// Balanced quality and cost. Recommended for most users.
    case balanced

    /// Highest quality. Best for complex or technical skills.
    case best

    // MARK: - Persistence

    nonisolated static let userDefaultsKey = "ai.selectedModelTier"

    /// Reads the persisted tier from UserDefaults. Defaults to `.balanced`.
    nonisolated static var persisted: AIModelTier {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        return AIModelTier(rawValue: raw) ?? .balanced
    }

    /// Writes this tier to UserDefaults.
    func persist() {
        UserDefaults.standard.set(rawValue, forKey: AIModelTier.userDefaultsKey)
    }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .fast:     String(localized: "Fast")
        case .balanced: String(localized: "Balanced")
        case .best:     String(localized: "Best")
        }
    }

    var speedHint: String {
        switch self {
        case .fast:     String(localized: "3–5 sec")
        case .balanced: String(localized: "5–10 sec")
        case .best:     String(localized: "10–20 sec")
        }
    }

    var qualityDescription: String {
        switch self {
        case .fast:     String(localized: "Lightweight model, great for everyday practice")
        case .balanced: String(localized: "Strong quality at reasonable cost — recommended")
        case .best:     String(localized: "Most capable model, ideal for complex topics")
        }
    }

    // MARK: - Model IDs

    /// Model ID used for challenge generation at this tier.
    ///
    /// Generation scales with tier — higher tier means a more capable model.
    nonisolated func generationModelID(for provider: AIProvider) -> String {
        switch (self, provider) {
        case (.fast,     .claude): "claude-haiku-4-5-20251001"
        case (.balanced, .claude): "claude-sonnet-4-20250514"
        case (.best,     .claude): "claude-opus-4-5"

        case (.fast,     .openai): "gpt-4o-mini"
        case (.balanced, .openai): "gpt-4o"
        case (.best,     .openai): "gpt-4o"

        case (.fast,     .gemini): "gemini-2.0-flash"
        case (.balanced, .gemini): "gemini-1.5-pro"
        case (.best,     .gemini): "gemini-1.5-pro"
        }
    }

    /// Model ID used for answer evaluation.
    ///
    /// Evaluation always uses the fast model regardless of tier
    /// to keep latency and cost predictable.
    nonisolated func evalModelID(for provider: AIProvider) -> String {
        switch provider {
        case .claude: "claude-haiku-4-5-20251001"
        case .openai: "gpt-4o-mini"
        case .gemini: "gemini-2.0-flash"
        }
    }

    // MARK: - Cost Hints

    /// Approximate cost per practice session for the given provider.
    func costHint(for provider: AIProvider) -> String {
        switch (self, provider) {
        case (.fast,     .claude): "~$0.001 per session"
        case (.balanced, .claude): "~$0.01 per session"
        case (.best,     .claude): "~$0.05 per session"

        case (.fast,     .openai): "~$0.001 per session"
        case (.balanced, .openai): "~$0.01 per session"
        case (.best,     .openai): "~$0.01 per session"

        case (.fast,     .gemini): "~$0.001 per session"
        case (.balanced, .gemini): "~$0.005 per session"
        case (.best,     .gemini): "~$0.005 per session"
        }
    }
}
