import SwiftUI

// MARK: - Skill Category

/// The category a skill belongs to, determining its accent color and SF Symbol icon.
enum SkillCategory: String, CaseIterable, Codable, Sendable {
    case programming = "Programming"
    case language    = "Language"
    case tool        = "Tool"
    case concept     = "Concept"
    case custom      = "Custom"

    /// The design-system accent color for this category.
    var color: Color {
        switch self {
        case .programming: .sdtCategoryProgramming
        case .language:    .sdtCategoryLanguage
        case .tool:        .sdtCategoryTool
        case .concept:     .sdtCategoryConcept
        case .custom:      .sdtCategoryCustom
        }
    }

    /// The SF Symbol name for this category.
    var systemImage: String {
        switch self {
        case .programming: "chevron.left.forwardslash.chevron.right"
        case .language:    "character.book.closed"
        case .tool:        "wrench.and.screwdriver"
        case .concept:     "lightbulb"
        case .custom:      "star"
        }
    }

    /// Localised display name for this category.
    var displayName: String {
        switch self {
        case .programming: String(localized: "Programming")
        case .language:    String(localized: "Language")
        case .tool:        String(localized: "Tool")
        case .concept:     String(localized: "Concept")
        case .custom:      String(localized: "Custom")
        }
    }
}

// MARK: - Health Color Resolution

extension Color {
    /// Returns the semantic health color for a score in the range 0…1.
    ///
    /// | Range      | Color    | State    |
    /// |------------|----------|----------|
    /// | 0.9 – 1.0  | Emerald  | Thriving |
    /// | 0.7 – 0.89 | Teal     | Healthy  |
    /// | 0.5 – 0.69 | Amber    | Fading   |
    /// | 0.3 – 0.49 | Orange   | Wilting  |
    /// | 0.0 – 0.29 | Rose     | Critical |
    static func sdtHealth(for score: Double) -> Color {
        switch score {
        case 0.9...: .sdtHealthThriving
        case 0.7...: .sdtHealthHealthy
        case 0.5...: .sdtHealthFading
        case 0.3...: .sdtHealthWilting
        default:     .sdtHealthCritical
        }
    }

    /// Human-readable label for a given health score.
    static func sdtHealthLabel(for score: Double) -> String {
        switch score {
        case 0.9...: String(localized: "Thriving")
        case 0.7...: String(localized: "Healthy")
        case 0.5...: String(localized: "Fading")
        case 0.3...: String(localized: "Wilting")
        default:     String(localized: "Critical")
        }
    }
}

// MARK: - Animation Constants

/// Shared animation presets to keep motion consistent across the app.
enum SDTAnimation {
    /// Spring used for score changes and card reveals — duration 0.6, bounce 0.2.
    static let scoreChange    = Animation.spring(duration: 0.6, bounce: 0.2)

    /// Subtle pulse for healthy skills — 2 s linear repeat.
    static let healthyPulse   = Animation.linear(duration: 2).repeatForever(autoreverses: true)

    /// Desaturation wave for decaying skills — 5 s linear repeat.
    static let decayShimmer   = Animation.linear(duration: 5).repeatForever(autoreverses: false)

    /// Standard stagger delay between list items (e.g. challenge options).
    static let itemStagger: Double = 0.1
}
