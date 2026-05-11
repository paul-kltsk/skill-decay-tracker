import SwiftUI

// MARK: - Typography System

/// Design-system typography tokens.
///
/// Use with the `sdtFont(_:color:)` View extension:
/// ```swift
/// Text("Score").sdtFont(.healthScore, color: .sdtHealthHealthy)
/// Text("Section").sdtFont(.titleMedium)
/// ```
///
/// | Case            | Typeface        | Size | Weight   |
/// |-----------------|-----------------|------|----------|
/// | `.healthScore`  | SF Pro Rounded  |  48  | Heavy    |
/// | `.numericLarge` | SF Pro Rounded  |  36  | Heavy    |
/// | `.numericMedium`| SF Pro Rounded  |  24  | Bold     |
/// | `.titleLarge`   | SF Pro Rounded  |  34  | Heavy    |
/// | `.titleMedium`  | SF Pro Rounded  |  28  | Bold     |
/// | `.titleSmall`   | SF Pro Rounded  |  22  | Bold     |
/// | `.bodyLarge`    | SF Pro          |  17  | Regular  |
/// | `.bodySemibold` | SF Pro          |  17  | Semibold |
/// | `.bodyMedium`   | SF Pro          |  15  | Regular  |
/// | `.caption`      | SF Pro          |  13  | Regular  |
/// | `.captionSemibold`| SF Pro        |  13  | Semibold |
/// | `.codeMedium`   | SF Mono         |  15  | Medium   |
/// | `.codeSmall`    | SF Mono         |  13  | Medium   |
enum SDTTypography {

    // MARK: Rounded — SF Pro Rounded (Titles & Numerics)

    /// 48 pt Heavy Rounded — health score display.
    case healthScore
    /// 36 pt Heavy Rounded — XP totals, streak counts.
    case numericLarge
    /// 24 pt Bold Rounded — card callouts, section numerics.
    case numericMedium
    /// 34 pt Heavy Rounded — screen titles.
    case titleLarge
    /// 28 pt Bold Rounded — section headers.
    case titleMedium
    /// 22 pt Bold Rounded — card titles, sheet headings.
    case titleSmall

    // MARK: Default — SF Pro (Body & UI)

    /// 17 pt Regular — primary body copy.
    case bodyLarge
    /// 17 pt Semibold — emphasized body labels.
    case bodySemibold
    /// 15 pt Regular — secondary body, list rows.
    case bodyMedium
    /// 13 pt Regular — captions, metadata.
    case caption
    /// 13 pt Semibold — emphasized captions, chip labels.
    case captionSemibold

    // MARK: Monospaced — SF Mono (Code Content)

    /// 15 pt Medium Mono — inline code, challenge code blocks.
    case codeMedium
    /// 13 pt Medium Mono — small code snippets, identifiers.
    case codeSmall

    // MARK: - Font Resolution

    /// The `Font` value for this typography token.
    var font: Font {
        switch self {
        case .healthScore:    .system(size: 48, weight: .heavy,   design: .rounded)
        case .numericLarge:   .system(size: 36, weight: .heavy,   design: .rounded)
        case .numericMedium:  .system(size: 24, weight: .bold,    design: .rounded)
        case .titleLarge:     .system(size: 34, weight: .heavy,   design: .rounded)
        case .titleMedium:    .system(size: 28, weight: .bold,    design: .rounded)
        case .titleSmall:     .system(size: 22, weight: .bold,    design: .rounded)
        case .bodyLarge:      .system(size: 17, weight: .regular)
        case .bodySemibold:   .system(size: 17, weight: .semibold)
        case .bodyMedium:     .system(size: 15, weight: .regular)
        case .caption:        .system(size: 13, weight: .regular)
        case .captionSemibold:.system(size: 13, weight: .semibold)
        case .codeMedium:     .system(size: 15, weight: .medium,  design: .monospaced)
        case .codeSmall:      .system(size: 13, weight: .medium,  design: .monospaced)
        }
    }
}
