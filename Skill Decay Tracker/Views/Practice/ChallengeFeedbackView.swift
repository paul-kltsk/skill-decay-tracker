import SwiftUI

/// Shows correct/wrong feedback with animation after a challenge is answered.
///
/// - Correct: spring-in checkmark, green ring, `haptic .success`
/// - Wrong: shake, red flash, `haptic .warning`
struct ChallengeFeedbackView: View {

    let challenge: Challenge
    let result: EvaluationResult
    let onNext: () -> Void

    @State private var appeared = false
    @State private var ringProgress = 0.0
    @State private var shake = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SDTSpacing.xl) {
                    resultBanner
                    feedbackCard
                    correctAnswerCard
                }
                .padding(.horizontal, SDTSpacing.lg)
                .padding(.top, SDTSpacing.xxxl)
                .padding(.bottom, SDTSpacing.xxxl)
            }

            nextButton
                .padding(.horizontal, SDTSpacing.lg)
                .padding(.bottom, SDTSpacing.xl)
        }
        .background(Color.sdtBackground)
        .task { await triggerAnimation() }
    }

    // MARK: - Banner

    private var resultBanner: some View {
        VStack(spacing: SDTSpacing.md) {
            ZStack {
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        result.isCorrect ? Color.sdtHealthThriving : Color.sdtHealthCritical,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 96, height: 96)
                    .animation(SDTAnimation.scoreChange, value: ringProgress)

                Image(systemName: result.isCorrect ? "checkmark" : "xmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(result.isCorrect ? Color.sdtHealthThriving : Color.sdtHealthCritical)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .animation(SDTAnimation.scoreChange, value: appeared)
            }
            .shakeEffect(trigger: shake)

            Text(result.isCorrect ? "Correct!" : "Not quite")
                .sdtFont(.titleMedium,
                         color: result.isCorrect ? .sdtHealthThriving : .sdtHealthCritical)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
                .animation(SDTAnimation.scoreChange.delay(0.15), value: appeared)
        }
    }

    // MARK: - Feedback Card

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            Label("Feedback", systemImage: "bubble.left.and.bubble.right")
                .sdtFont(.captionSemibold, color: .sdtSecondary)

            Text(result.feedback)
                .sdtFont(.bodyMedium)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sdtCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(SDTAnimation.scoreChange.delay(0.25), value: appeared)
    }

    // MARK: - Correct Answer Card (only when wrong)

    @ViewBuilder
    private var correctAnswerCard: some View {
        if !result.isCorrect && !challenge.correctAnswer.isEmpty {
            VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                Label("Correct answer", systemImage: "checkmark.seal")
                    .sdtFont(.captionSemibold, color: .sdtHealthThriving)

                Text(challenge.correctAnswer)
                    .sdtFont(challenge.type == .codeCompletion ? .codeMedium : .bodyMedium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SDTSpacing.lg)
            .background(Color.sdtHealthThriving.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                    .strokeBorder(Color.sdtHealthThriving.opacity(0.3), lineWidth: 1)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(SDTAnimation.scoreChange.delay(0.35), value: appeared)
        }
    }

    // MARK: - Next Button

    private var nextButton: some View {
        Button("Continue", action: onNext)
            .buttonStyle(SessionButtonStyle(
                tint: result.isCorrect ? .sdtHealthThriving : .sdtCategoryProgramming
            ))
    }

    // MARK: - Trigger

    private func triggerAnimation() async {
        appeared = true
        withAnimation(SDTAnimation.scoreChange) {
            ringProgress = 1.0
        }
        if !result.isCorrect {
            try? await Task.sleep(for: .milliseconds(100))
            shake = true
        }
    }
}
