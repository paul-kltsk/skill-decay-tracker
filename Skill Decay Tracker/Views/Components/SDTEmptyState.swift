import SwiftUI

/// Reusable empty-state placeholder with an SF Symbol icon, title, and message.
///
/// Used by tab views while full implementations are pending, and by feature
/// screens when there is no data to display.
struct SDTEmptyState: View {

    // MARK: Configuration

    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    /// Optional call-to-action label + action closure.
    var actionLabel: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    // MARK: Body

    var body: some View {
        VStack(spacing: SDTSpacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.sdtSecondary)

            VStack(spacing: SDTSpacing.sm) {
                Text(title)
                    .sdtFont(.titleMedium)

                Text(message)
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            }

            if let label = actionLabel, let action {
                Button(label, action: action)
                    .buttonStyle(SDTButtonStyle(tier: .primary))
            }
        }
        .padding(SDTSpacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Minimal SDTButtonStyle (primary tier only)

/// Lightweight primary button style used by `SDTEmptyState`.
///
/// The full `SDTButton` component is implemented separately; this style
/// is a self-contained fallback so `SDTEmptyState` compiles without it.
private struct SDTButtonStyle: ButtonStyle {
    enum Tier { case primary }
    let tier: Tier

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sdtFont(.bodyLarge, color: .white)
            .padding(.vertical, SDTSpacing.md)
            .padding(.horizontal, SDTSpacing.xl)
            .background(Color.sdtCategoryProgramming)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    SDTEmptyState(
        icon: "sparkles",
        title: "No Skills Yet",
        message: "Add your first skill to start tracking your knowledge.",
        actionLabel: "Add Skill",
        action: {}
    )
}
