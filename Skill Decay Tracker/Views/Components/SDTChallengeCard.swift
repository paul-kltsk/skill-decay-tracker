import SwiftUI

/// Header card displayed at the top of each challenge screen.
///
/// Shows the challenge type badge, difficulty dots, session progress indicator,
/// and a countdown timer bar that changes colour as time runs low.
struct SDTChallengeCard: View {

    let challenge: Challenge
    /// Timer progress 0…1 (1.0 = full time remaining, 0.0 = expired).
    let timerProgress: Double
    let questionIndex: Int
    let totalQuestions: Int

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            topRow
            timerBar
            questionText
        }
        .padding(SDTSpacing.lg)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Subviews

    private var topRow: some View {
        HStack(spacing: SDTSpacing.sm) {
            Label(challenge.type.displayName, systemImage: challenge.type.systemImage)
                .sdtFont(.captionSemibold, color: typeColor)
                .padding(.horizontal, SDTSpacing.sm)
                .padding(.vertical, SDTSpacing.xxs)
                .background(typeColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip))

            Spacer()

            sessionProgressDots
        }
    }

    private var timerBar: some View {
        SDTProgressBar(value: timerProgress, tint: timerColor)
            .frame(height: 3)
    }

    private var questionText: some View {
        Text(challenge.question)
            .sdtFont(.bodyLarge)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Progress dots showing which question in the session the user is on.
    /// Each dot represents one question; filled dots = completed or current.
    private var sessionProgressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalQuestions, id: \.self) { index in
                Circle()
                    .fill(index <= questionIndex
                          ? typeColor
                          : Color.sdtSecondary.opacity(0.2))
                    .frame(width: 7, height: 7)
                    .animation(SDTAnimation.scoreChange, value: questionIndex)
            }
        }
    }

    // MARK: - Computed Colours

    private var typeColor: Color {
        challenge.skill?.category.color ?? .sdtCategoryProgramming
    }

    private var timerColor: Color {
        switch timerProgress {
        case 0.5...: return .sdtHealthHealthy
        case 0.25...: return .sdtHealthFading
        default:     return .sdtHealthCritical
        }
    }
}
