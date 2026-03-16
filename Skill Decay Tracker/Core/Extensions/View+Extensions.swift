import SwiftUI

// MARK: - SDT View Modifiers

extension View {

    // MARK: Typography

    /// Applies an SDT typography style with an optional foreground color.
    ///
    /// Usage:
    /// ```swift
    /// Text("Health").sdtFont(.titleLarge)
    /// Text("78%").sdtFont(.healthScore, color: .sdtHealthHealthy)
    /// ```
    func sdtFont(_ style: SDTTypography, color: Color? = nil) -> some View {
        self
            .font(style.font)
            .foregroundStyle(color ?? .sdtPrimary)
    }

    // MARK: Card Surface

    /// Wraps the view in a standard SDT card: surface background, 16-pt rounded rectangle, subtle shadow.
    func sdtCard(padding: CGFloat = SDTSpacing.lg) -> some View {
        self
            .padding(padding)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: Minimum Tap Target

    /// Expands the hit-testing area to at least 44×44 pt without changing layout size.
    func minTapTarget() -> some View {
        self.frame(
            minWidth:  SDTSpacing.minTapTarget,
            minHeight: SDTSpacing.minTapTarget
        )
    }

    // MARK: Conditional Modifier

    /// Applies `transform` when `condition` is `true`.
    ///
    /// Prefer dedicated view modifiers where possible; use this only for
    /// one-off optional styling.
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    // MARK: Shake Gesture (wrong-answer feedback)

    /// Plays the "wrong answer" shake animation.
    ///
    /// Drive it by toggling a `@State var shake: Bool`.
    func shakeEffect(trigger: Bool) -> some View {
        self.modifier(ShakeModifier(trigger: trigger))
    }
}

// MARK: - Shake Modifier

private struct ShakeModifier: ViewModifier {
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, offset in
                view.offset(x: offset)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe( 0,   duration: 0.04)
                    LinearKeyframe(-10,  duration: 0.08)
                    LinearKeyframe( 10,  duration: 0.08)
                    LinearKeyframe(-5,   duration: 0.06)
                    LinearKeyframe( 5,   duration: 0.06)
                    LinearKeyframe( 0,   duration: 0.04)
                }
            }
    }
}
