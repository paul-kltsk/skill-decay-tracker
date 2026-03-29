import Foundation

// MARK: - AIProvider

/// Supported AI providers for challenge generation and answer evaluation.
///
/// The active provider is persisted in `UserPreferences.aiProvider` (SwiftData)
/// and mirrored to `UserDefaults` under `"ai.selectedProvider"` so that
/// `AIService` — an `actor` without SwiftData access — can read it cheaply.
enum AIProvider: String, Codable, CaseIterable, Sendable {
    case claude = "claude"
    case openai = "openai"
    case gemini = "gemini"
}

// MARK: - Display Metadata

extension AIProvider {

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .openai: "ChatGPT"
        case .gemini: "Gemini"
        }
    }

    var companyName: String {
        switch self {
        case .claude: "Anthropic"
        case .openai: "OpenAI"
        case .gemini: "Google"
        }
    }

    var tagline: String {
        switch self {
        case .claude: "Best reasoning & long-context understanding"
        case .openai: "Broad knowledge, fast responses"
        case .gemini: "Google's multimodal AI — fast & free tier"
        }
    }

    /// Model used for challenge generation (quality-first).
    nonisolated var generationModelID: String {
        switch self {
        case .claude: "claude-sonnet-4-20250514"
        case .openai: "gpt-4o-mini"
        case .gemini: "gemini-2.0-flash"
        }
    }

    /// Model used for answer evaluation (speed-first).
    nonisolated var evalModelID: String {
        switch self {
        case .claude: "claude-haiku-4-5-20251001"
        case .openai: "gpt-4o-mini"
        case .gemini: "gemini-2.0-flash"
        }
    }

    /// Human-readable model label shown in the UI.
    var modelLabel: String {
        switch self {
        case .claude: "Sonnet 4 · Haiku 4.5"
        case .openai: "GPT-4o Mini"
        case .gemini: "Gemini 2.0 Flash"
        }
    }

    /// Expected prefix of a valid API key for this provider.
    var keyPrefix: String {
        switch self {
        case .claude: "sk-ant-"
        case .openai: "sk-"
        case .gemini: "AIza"
        }
    }

    /// URL where the user can obtain an API key.
    var apiConsoleURL: URL {
        switch self {
        case .claude: URL(staticString: "https://console.anthropic.com/settings/keys")
        case .openai: URL(staticString: "https://platform.openai.com/api-keys")
        case .gemini: URL(staticString: "https://aistudio.google.com/app/apikey")
        }
    }

    /// SF Symbol representing this provider.
    var systemImage: String {
        switch self {
        case .claude: "sparkle"
        case .openai: "bolt.circle"
        case .gemini: "g.circle"
        }
    }

    // MARK: - UserDefaults

    nonisolated static let userDefaultsKey = "ai.selectedProvider"

    /// Reads the currently persisted provider from `UserDefaults`.
    /// Falls back to `.claude` if nothing is stored.
    ///
    /// Explicitly `nonisolated` to override `@MainActor` inference that propagates
    /// from the synthesised `Codable` conformance used by `UserProfile @Model`.
    nonisolated static var persisted: AIProvider {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        return AIProvider(rawValue: raw) ?? .claude
    }

    /// Writes this provider to `UserDefaults` for fast actor-level reads.
    func persist() {
        UserDefaults.standard.set(rawValue, forKey: AIProvider.userDefaultsKey)
    }

    // MARK: - Key Validation

    /// Returns `true` if `key` looks syntactically valid for this provider.
    func isValidKey(_ key: String) -> Bool {
        let t = key.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix(keyPrefix) && t.count > keyPrefix.count + 8
    }
}
