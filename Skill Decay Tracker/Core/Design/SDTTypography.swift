import SwiftUI

// MARK: - Typography System

/// Font constants for the Skill Decay Tracker design system.
///
/// | Role         | Typeface        | Usage                         |
/// |--------------|-----------------|-------------------------------|
/// | `.rounded`   | SF Pro Rounded  | Titles, numerics, health score |
/// | `.default`   | SF Pro          | Body text, labels              |
/// | `.monospaced`| SF Mono         | Code snippets, identifiers     |
enum SDTTypography {

    // MARK: - Rounded — SF Pro Rounded (Titles & Numerics)

    /// 48 pt Heavy Rounded — health score display.
    static let healthScore: Font   = .system(size: 48, weight: .heavy,   design: .rounded)

    /// 36 pt Heavy Rounded — XP totals, streak counts.
    static let numericLarge: Font  = .system(size: 36, weight: .heavy,   design: .rounded)

    /// 24 pt Bold Rounded — section numerics, card callouts.
    static let numericMedium: Font = .system(size: 24, weight: .bold,    design: .rounded)

    /// 34 pt Heavy Rounded — screen titles.
    static let titleLarge: Font    = .system(size: 34, weight: .heavy,   design: .rounded)

    /// 28 pt Bold Rounded — section headers.
    static let titleMedium: Font   = .system(size: 28, weight: .bold,    design: .rounded)

    /// 22 pt Bold Rounded — card titles, sheet headings.
    static let titleSmall: Font    = .system(size: 22, weight: .bold,    design: .rounded)

    // MARK: - Default — SF Pro (Body & UI)

    /// 17 pt Regular — primary body copy.
    static let bodyLarge: Font     = .system(size: 17, weight: .regular)

    /// 17 pt Semibold — emphasized body labels.
    static let bodySemibold: Font  = .system(size: 17, weight: .semibold)

    /// 15 pt Regular — secondary body, list rows.
    static let bodyMedium: Font    = .system(size: 15, weight: .regular)

    /// 13 pt Regular — captions, metadata.
    static let caption: Font       = .system(size: 13, weight: .regular)

    /// 13 pt Semibold — emphasized captions, chip labels.
    static let captionSemibold: Font = .system(size: 13, weight: .semibold)

    // MARK: - Monospaced — SF Mono (Code Content)

    /// 15 pt Medium Mono — inline code, challenge code blocks.
    static let codeMedium: Font    = .system(size: 15, weight: .medium,  design: .monospaced)

    /// 13 pt Medium Mono — small code snippets, identifiers.
    static let codeSmall: Font     = .system(size: 13, weight: .medium,  design: .monospaced)
}

// MARK: - View Extension

extension View {
    /// Applies a design-system font and foreground style in one call.
    ///
    /// ```swift
    /// Text("Score").sdtFont(.healthScore, color: .sdtPrimary)
    /// ```
    func sdtFont(_ font: Font, color: Color = .sdtPrimary) -> some View {
        self
            .font(font)
            .foregroundStyle(color)
    }
}
