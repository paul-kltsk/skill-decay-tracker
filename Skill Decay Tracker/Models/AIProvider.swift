import Foundation
import SwiftUI

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
        case .claude: String(localized: "Best reasoning & long-context understanding")
        case .openai: String(localized: "Broad knowledge, fast responses")
        case .gemini: String(localized: "Google's multimodal AI — fast & free tier")
        }
    }

    /// Human-readable label showing the currently selected generation and evaluation models.
    var modelLabel: String {
        let gen  = AIModelTier.persisted.modelDisplayName(for: self)
        let eval = AIModelTier.persistedEval.modelDisplayName(for: self)
        return gen == eval ? gen : "\(gen) · \(eval)"
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
        // Safe: all strings are hardcoded compile-time literals, never nil.
        switch self {
        case .claude: URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai: URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")!
        }
    }

    /// SF Symbol representing this provider (used as fallback).
    var systemImage: String {
        switch self {
        case .claude: "sparkle"
        case .openai: "bolt.circle"
        case .gemini: "g.circle"
        }
    }

    /// Asset-catalog icon for this provider.
    var iconImage: Image {
        switch self {
        case .claude: Image("claude_icon")
        case .openai: Image("gpt_icon")
        case .gemini: Image("gemini_icon")
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
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix(keyPrefix) && t.count > keyPrefix.count + 8
    }
}
