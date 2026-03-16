import CoreFoundation

// MARK: - Spacing Scale

/// Spacing constants for the Skill Decay Tracker design system.
///
/// Use these values for padding and stack spacing throughout the app
/// instead of hard-coded literals.
///
/// ```swift
/// VStack(spacing: SDTSpacing.md) { ... }
///     .padding(.horizontal, SDTSpacing.lg)
/// ```
enum SDTSpacing {
    static let xxs: CGFloat  =  2
    static let xs:  CGFloat  =  4
    static let sm:  CGFloat  =  8
    static let md:  CGFloat  = 12
    static let lg:  CGFloat  = 16
    static let xl:  CGFloat  = 24
    static let xxl: CGFloat  = 32
    static let xxxl: CGFloat = 48

    // MARK: - Corner Radii

    /// Corner radius tokens for `clipShape(RoundedRectangle(cornerRadius:))`.
    enum CornerRadius {
        /// Cards, sheets, skill detail surfaces — 16 pt
        static let card:   CGFloat = 16
        /// Buttons, input fields — 12 pt
        static let button: CGFloat = 12
        /// Chips, tags, filter pills — 8 pt
        static let chip:   CGFloat =  8
    }

    // MARK: - Tap Target

    /// Apple's minimum recommended interactive tap target — 44 × 44 pt.
    static let minTapTarget: CGFloat = 44
}
