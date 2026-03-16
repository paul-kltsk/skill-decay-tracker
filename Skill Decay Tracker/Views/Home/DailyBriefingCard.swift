import SwiftUI

/// A card shown at the top of ``HomeView`` summarising the day's practice situation.
///
/// Displays portfolio health ring, overdue-skill count, and a CTA to start a session.
struct DailyBriefingCard: View {

    /// Average health across all skills (0…1).
    let portfolioHealth: Double
    /// Number of skills that are overdue for review.
    let overdueCount: Int
    /// Longest current streak across all skills (for motivation display).
    let topStreakDays: Int
    /// Called when the user taps "Start Review".
    var onStartReview: () -> Void = {}

    var body: some View {
        HStack(spacing: SDTSpacing.xl) {
            healthSection
            Spacer(minLength: 0)
            rightSection
        }
        .padding(SDTSpacing.lg)
        .background(briefingGradient)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    // MARK: - Subviews

    private var healthSection: some View {
        ZStack {
            SDTHealthRing(score: portfolioHealth, lineWidth: 10)
                .frame(width: 80, height: 80)

            VStack(spacing: 0) {
                Text("\(Int((portfolioHealth * 100).rounded()))%")
                    .sdtFont(.titleSmall, color: .white)
                Text(Color.sdtHealthLabel(for: portfolioHealth))
                    .sdtFont(.caption, color: .white.opacity(0.8))
            }
        }
    }

    private var rightSection: some View {
        VStack(alignment: .trailing, spacing: SDTSpacing.sm) {
            overdueLabel

            if topStreakDays > 0 {
                SDTStreakBadge(days: topStreakDays)
            }

            if overdueCount > 0 {
                startButton
            }
        }
    }

    private var overdueLabel: some View {
        Group {
            if overdueCount == 0 {
                Label("All caught up!", systemImage: "checkmark.seal.fill")
                    .sdtFont(.captionSemibold, color: .white.opacity(0.9))
            } else {
                Text("\(overdueCount) skill\(overdueCount == 1 ? "" : "s") need review")
                    .sdtFont(.captionSemibold, color: .white.opacity(0.9))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var startButton: some View {
        Button(action: onStartReview) {
            Text("Start Review")
                .sdtFont(.captionSemibold, color: .white)
                .padding(.vertical, SDTSpacing.xs)
                .padding(.horizontal, SDTSpacing.md)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip))
        }
        .minTapTarget()
        .sensoryFeedback(.impact(flexibility: .soft), trigger: true)
    }

    // MARK: - Background Gradient

    private var briefingGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.sdtHealth(for: portfolioHealth),
                Color.sdtHealth(for: max(0, portfolioHealth - 0.2)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        DailyBriefingCard(portfolioHealth: 0.82, overdueCount: 3, topStreakDays: 7)
        DailyBriefingCard(portfolioHealth: 0.45, overdueCount: 1, topStreakDays: 0)
        DailyBriefingCard(portfolioHealth: 0.95, overdueCount: 0, topStreakDays: 14)
    }
    .padding()
}
