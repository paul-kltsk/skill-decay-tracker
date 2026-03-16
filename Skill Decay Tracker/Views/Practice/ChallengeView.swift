import SwiftUI
import SwiftData

/// Hosts the active practice session — routes between challenge, feedback, and complete screens.
///
/// Created by ``SessionLauncherView`` and presented as `.fullScreenCover`.
struct ChallengeView: View {

    @Bindable var viewModel: PracticeViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        switch viewModel.phase {
        case .loading:
            LoadingSessionView()
        case .inChallenge, .evaluating:
            ActiveChallengeView(viewModel: viewModel, modelContext: modelContext)
        case .showingFeedback:
            if let eval = viewModel.evaluationResult, let challenge = viewModel.currentChallenge {
                ChallengeFeedbackView(
                    challenge: challenge,
                    result: eval,
                    onNext: { viewModel.nextChallenge() }
                )
            }
        case .sessionComplete:
            if let summary = viewModel.summary {
                SessionCompleteView(summary: summary) {
                    viewModel.endSession()
                }
            }
        case .error(let message):
            ErrorSessionView(message: message) {
                viewModel.endSession()
            }
        case .idle:
            EmptyView()
        }
    }
}

// MARK: - Loading Screen

private struct LoadingSessionView: View {
    var body: some View {
        VStack(spacing: SDTSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.sdtCategoryProgramming)
            Text("Building your session…")
                .sdtFont(.bodyMedium, color: .sdtSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sdtBackground)
    }
}

// MARK: - Error Screen

private struct ErrorSessionView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: SDTSpacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.sdtHealthWilting)
            Text(message)
                .sdtFont(.bodyMedium, color: .sdtSecondary)
                .multilineTextAlignment(.center)
            Button("Got it", action: onDismiss)
                .buttonStyle(SessionButtonStyle(tint: .sdtCategoryProgramming))
        }
        .padding(SDTSpacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sdtBackground)
    }
}

// MARK: - Active Challenge

private struct ActiveChallengeView: View {

    @Bindable var viewModel: PracticeViewModel
    let modelContext: ModelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SDTSpacing.lg) {
                    if let challenge = viewModel.currentChallenge {
                        SDTChallengeCard(
                            challenge: challenge,
                            timerProgress: viewModel.timerProgress,
                            questionIndex: viewModel.currentIndex,
                            totalQuestions: viewModel.challenges.count
                        )

                        answerSection(for: challenge)
                    }
                }
                .padding(.horizontal, SDTSpacing.lg)
                .padding(.bottom, SDTSpacing.xxxl)
            }
            .background(Color.sdtBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { sessionToolbar }
            .safeAreaInset(edge: .bottom) {
                if viewModel.phase == .inChallenge {
                    submitBar
                }
            }
        }
    }

    // MARK: Answer Sections

    @ViewBuilder
    private func answerSection(for challenge: Challenge) -> some View {
        switch challenge.type {
        case .multipleChoice:
            MultipleChoiceView(options: challenge.options, selected: viewModel.selectedOption) {
                viewModel.selectOption($0)
            }
        case .trueFalse:
            TrueFalseView(selected: viewModel.selectedOption) {
                viewModel.selectOption($0)
            }
        case .openEnded:
            OpenEndedView(answer: $viewModel.userAnswer, multiline: true)
        case .fillInTheBlank:
            OpenEndedView(answer: $viewModel.userAnswer, multiline: false)
        case .codeCompletion:
            CodeCompletionView(answer: $viewModel.userAnswer)
        }
    }

    // MARK: Submit Bar

    private var submitBar: some View {
        VStack(spacing: SDTSpacing.sm) {
            if viewModel.phase == .evaluating {
                ProgressView("Evaluating…")
                    .tint(.sdtCategoryProgramming)
                    .frame(maxWidth: .infinity)
                    .padding(SDTSpacing.lg)
                    .background(Color.sdtSurface)
            } else {
                HStack(spacing: SDTSpacing.md) {
                    Button("Skip") {
                        viewModel.skipChallenge(context: modelContext)
                    }
                    .buttonStyle(SessionButtonStyle(tint: .sdtSecondary, outlined: true))
                    .frame(width: 90)

                    Button("Submit") {
                        Task { await viewModel.submitAnswer(context: modelContext) }
                    }
                    .buttonStyle(SessionButtonStyle(tint: .sdtCategoryProgramming))
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, SDTSpacing.lg)
                .padding(.vertical, SDTSpacing.md)
                .background(Color.sdtBackground)
            }
        }
    }

    private var canSubmit: Bool {
        !viewModel.userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || viewModel.selectedOption != nil
    }

    // MARK: Toolbar

    private var sessionToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.endSession()
            } label: {
                Image(systemName: "xmark")
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Answer Input Views

private struct MultipleChoiceView: View {
    let options: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: SDTSpacing.sm) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                OptionButton(
                    label: option,
                    prefix: ["A", "B", "C", "D"][safe: index] ?? "\(index + 1)",
                    isSelected: selected == option,
                    onTap: { onSelect(option) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(
                    SDTAnimation.scoreChange.delay(Double(index) * SDTAnimation.itemStagger),
                    value: options
                )
            }
        }
    }
}

private struct TrueFalseView: View {
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: SDTSpacing.md) {
            ForEach(["True", "False"], id: \.self) { option in
                OptionButton(
                    label: option,
                    prefix: option == "True" ? "✓" : "✗",
                    isSelected: selected == option,
                    onTap: { onSelect(option) }
                )
            }
        }
    }
}

private struct OpenEndedView: View {
    @Binding var answer: String
    let multiline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.xs) {
            Text("Your answer")
                .sdtFont(.captionSemibold, color: .sdtSecondary)

            if multiline {
                TextEditor(text: $answer)
                    .sdtFont(.bodyLarge)
                    .frame(minHeight: 120)
                    .padding(SDTSpacing.sm)
                    .background(Color.sdtSurface)
                    .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                    .overlay {
                        RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                            .strokeBorder(Color.sdtSecondary.opacity(0.2), lineWidth: 1)
                    }
            } else {
                TextField("Type your answer…", text: $answer)
                    .sdtFont(.bodyLarge)
                    .padding(SDTSpacing.md)
                    .background(Color.sdtSurface)
                    .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                    .overlay {
                        RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                            .strokeBorder(Color.sdtSecondary.opacity(0.2), lineWidth: 1)
                    }
            }
        }
    }
}

private struct CodeCompletionView: View {
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.xs) {
            Text("Complete the code")
                .sdtFont(.captionSemibold, color: .sdtSecondary)

            TextEditor(text: $answer)
                .font(SDTTypography.codeMedium.font)
                .foregroundStyle(Color.sdtPrimary)
                .frame(minHeight: 140)
                .padding(SDTSpacing.sm)
                .background(Color.sdtSurface)
                .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                .overlay {
                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                        .strokeBorder(Color.sdtCategoryProgramming.opacity(0.3), lineWidth: 1)
                }
        }
    }
}

private struct OptionButton: View {
    let label: String
    let prefix: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SDTSpacing.md) {
                Text(prefix)
                    .sdtFont(.captionSemibold,
                             color: isSelected ? .white : .sdtSecondary)
                    .frame(width: 28, height: 28)
                    .background(isSelected
                                ? Color.sdtCategoryProgramming
                                : Color.sdtSecondary.opacity(0.12))
                    .clipShape(Circle())

                Text(label)
                    .sdtFont(.bodyMedium,
                             color: isSelected ? .sdtCategoryProgramming : .sdtPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(SDTSpacing.md)
            .background(isSelected
                        ? Color.sdtCategoryProgramming.opacity(0.08)
                        : Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
            .overlay {
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                    .strokeBorder(
                        isSelected ? Color.sdtCategoryProgramming : Color.sdtSecondary.opacity(0.2),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .minTapTarget()
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isSelected)
        .animation(SDTAnimation.scoreChange, value: isSelected)
    }
}

// MARK: - Shared Button Style

struct SessionButtonStyle: ButtonStyle {
    let tint: Color
    var outlined = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sdtFont(.bodySemibold, color: outlined ? tint : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.md)
            .background(outlined ? Color.clear : tint.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
            .overlay {
                if outlined {
                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                        .strokeBorder(tint, lineWidth: 1.5)
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
