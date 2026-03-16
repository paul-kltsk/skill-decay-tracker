import SwiftUI

/// A compact flame badge that displays a consecutive-day practice streak.
///
/// The flame icon pulses using `PhaseAnimator` as defined in the design system.
///
/// ```swift
/// SDTStreakBadge(days: skill.streakDays)
/// ```
struct SDTStreakBadge: View {

    /// Number of consecutive days practiced.
    let days: Int

    var body: some View {
        HStack(spacing: SDTSpacing.xxs) {
            PhaseAnimator([false, true]) { pulsing in
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
                    .scaleEffect(pulsing ? 1.15 : 1.0)
            } animation: { _ in
                SDTAnimation.healthyPulse
            }

            Text("\(days)")
                .sdtFont(.captionSemibold, color: .sdtPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) day streak")
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        SDTStreakBadge(days: 1)
        SDTStreakBadge(days: 7)
        SDTStreakBadge(days: 42)
    }
    .padding()
}
