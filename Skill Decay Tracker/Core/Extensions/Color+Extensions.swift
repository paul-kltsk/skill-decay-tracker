import SwiftUI

// MARK: - SDT Semantic Colors

extension Color {

    // MARK: Backgrounds

    /// Primary app background — adaptive light/dark.
    static let sdtBackground = Color("sdtBackground")

    /// Elevated surface (cards, sheets) — adaptive light/dark.
    static let sdtSurface = Color("sdtSurface")

    // MARK: Text / Icons

    /// Primary text and icon color — adaptive light/dark.
    static let sdtPrimary = Color("sdtPrimary")

    /// Secondary / muted text and icon color — adaptive light/dark.
    static let sdtSecondary = Color("sdtSecondary")

    // MARK: Health Gradient

    /// Emerald — Thriving (≥ 0.9).
    static let sdtHealthThriving = Color(hex: 0x059669)

    /// Teal — Healthy (0.7 – 0.89).
    static let sdtHealthHealthy  = Color(hex: 0x0D9488)

    /// Amber — Fading (0.5 – 0.69).
    static let sdtHealthFading   = Color(hex: 0xD97706)

    /// Orange — Wilting (0.3 – 0.49).
    static let sdtHealthWilting  = Color(hex: 0xEA580C)

    /// Rose — Critical (< 0.3).
    static let sdtHealthCritical = Color(hex: 0xE11D48)

    // MARK: Category Accents

    /// Indigo — Programming skills.
    static let sdtCategoryProgramming = Color(hex: 0x6366F1)

    /// Violet — Language skills.
    static let sdtCategoryLanguage    = Color(hex: 0x8B5CF6)

    /// Sky — Tool skills.
    static let sdtCategoryTool        = Color(hex: 0x0EA5E9)

    /// Fuchsia — Concept skills.
    static let sdtCategoryConcept     = Color(hex: 0xD946EF)

    /// Slate — Custom skills.
    static let sdtCategoryCustom      = Color(hex: 0x64748B)

    // MARK: Health Resolver

    /// Returns the semantic health color for the given score in `[0, 1]`.
    static func sdtHealth(for score: Double) -> Color {
        switch score {
        case 0.9...: return .sdtHealthThriving
        case 0.7...: return .sdtHealthHealthy
        case 0.5...: return .sdtHealthFading
        case 0.3...: return .sdtHealthWilting
        default:     return .sdtHealthCritical
        }
    }

    // MARK: - Hex Initializer

    /// Creates a `Color` from a 24-bit RGB hex literal, e.g. `Color(hex: 0x6366F1)`.
    ///
    /// Alpha is always 1.0.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
