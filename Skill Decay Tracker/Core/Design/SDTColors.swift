import SwiftUI

// MARK: - Hex Helpers

private extension UIColor {
    /// Creates a `UIColor` from a 24-bit hex integer (e.g. `0x059669`).
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8)  & 0xFF) / 255
        let b = CGFloat(hex         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// Creates a `Color` from a 24-bit RGB hex literal, e.g. `Color(hex: 0x6366F1)`.
    ///
    /// Alpha is always 1.0.  Used throughout the design system for fixed-palette colors.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Semantic Colors

extension Color {

    // MARK: Surface & Text

    /// Primary app background — adapts between light (#FAFBFC) and dark (#0D0D12).
    static let sdtBackground = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: 0x0D0D12)
            : UIColor(hex: 0xFAFBFC)
    })

    /// Card / sheet surface — adapts between light (#FFFFFF) and dark (#1A1A24).
    static let sdtSurface = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: 0x1A1A24)
            : UIColor(hex: 0xFFFFFF)
    })

    /// Primary text / prominent UI elements — adapts between light (#1B2A4A) and dark (#E8ECF4).
    static let sdtPrimary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: 0xE8ECF4)
            : UIColor(hex: 0x1B2A4A)
    })

    /// Secondary / subdued text — adapts between light (#6B7B98) and dark (#8B95A8).
    static let sdtSecondary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: 0x8B95A8)
            : UIColor(hex: 0x6B7B98)
    })

    /// Foreground for content placed on a `sdtPrimary`-filled surface.
    /// Light mode: white (#FFFFFF); dark mode: near-black (#0D0D12) — matches sdtBackground dark.
    static let sdtOnPrimary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: 0x0D0D12)
            : UIColor(hex: 0xFFFFFF)
    })

    // MARK: Health Gradient (fixed — same in light & dark)

    /// Health 0.9–1.0 — Emerald: Thriving
    static let sdtHealthThriving = Color(hex: 0x059669)
    /// Health 0.7–0.89 — Teal: Healthy
    static let sdtHealthHealthy  = Color(hex: 0x0D9488)
    /// Health 0.5–0.69 — Amber: Fading
    static let sdtHealthFading   = Color(hex: 0xD97706)
    /// Health 0.3–0.49 — Orange: Wilting
    static let sdtHealthWilting  = Color(hex: 0xEA580C)
    /// Health 0.0–0.29 — Rose: Critical
    static let sdtHealthCritical = Color(hex: 0xE11D48)

    // MARK: Category Accents (fixed — same in light & dark)

    /// Programming category — Indigo #6366F1
    static let sdtCategoryProgramming = Color(hex: 0x6366F1)
    /// Language category — Violet #8B5CF6
    static let sdtCategoryLanguage    = Color(hex: 0x8B5CF6)
    /// Tool category — Sky #0EA5E9
    static let sdtCategoryTool        = Color(hex: 0x0EA5E9)
    /// Concept category — Fuchsia #D946EF
    static let sdtCategoryConcept     = Color(hex: 0xD946EF)
    /// Custom category — Slate #64748B
    static let sdtCategoryCustom      = Color(hex: 0x64748B)
}
