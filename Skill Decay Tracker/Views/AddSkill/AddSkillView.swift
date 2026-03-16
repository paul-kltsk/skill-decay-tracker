import SwiftUI
import SwiftData

/// A 4-step modal wizard for adding a new skill to the portfolio.
///
/// Steps: **Name → Category → Difficulty → Confirm**
///
/// ```swift
/// .sheet(isPresented: $show) {
///     AddSkillView { newSkill in
///         prefetchChallenges(for: newSkill)
///     }
/// }
/// ```
struct AddSkillView: View {

    // MARK: - Dependencies

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddSkillViewModel()

    /// Called with the saved skill after the user taps "Add Skill".
    var onSkillCreated: ((Skill) -> Void)? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.horizontal, SDTSpacing.lg)
                    .padding(.top, SDTSpacing.md)

                TabView(selection: $viewModel.currentStep) {
                    NameStepView(viewModel: viewModel)
                        .tag(0)
                    CategoryStepView(viewModel: viewModel)
                        .tag(1)
                    DifficultyStepView(viewModel: viewModel)
                        .tag(2)
                    ConfirmStepView(viewModel: viewModel)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(SDTAnimation.scoreChange, value: viewModel.currentStep)

                navigationButtons
                    .padding(.horizontal, SDTSpacing.lg)
                    .padding(.bottom, SDTSpacing.xl)
            }
            .background(Color.sdtBackground)
            .navigationTitle("Add Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: SDTSpacing.sm) {
            ForEach(0..<4, id: \.self) { step in
                Capsule()
                    .fill(step <= viewModel.currentStep
                          ? viewModel.selectedCategory.color
                          : Color.sdtSecondary.opacity(0.25))
                    .frame(height: 4)
                    .animation(SDTAnimation.scoreChange, value: viewModel.currentStep)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: SDTSpacing.md) {
            if viewModel.currentStep > 0 {
                Button("Back") { viewModel.back() }
                    .buttonStyle(BackButtonStyle())
            }

            Button(viewModel.currentStep < 3 ? "Continue" : "Add Skill") {
                if viewModel.currentStep < 3 {
                    viewModel.advance()
                } else {
                    let skill = viewModel.save(context: modelContext)
                    onSkillCreated?(skill)
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: viewModel.selectedCategory.color))
            .disabled(!viewModel.canAdvance && viewModel.currentStep == 0)
        }
    }
}

// MARK: - Step 1: Name

private struct NameStepView: View {
    @Bindable var viewModel: AddSkillViewModel
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SDTSpacing.xl) {
                stepHeader(
                    icon: "pencil",
                    title: "What are you learning?",
                    subtitle: "Give your skill a clear, specific name."
                )

                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    TextField("e.g. SwiftUI, Japanese, Docker…", text: $viewModel.skillName)
                        .sdtFont(.bodyLarge)
                        .padding(SDTSpacing.md)
                        .background(Color.sdtSurface)
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                        .focused($focused)
                        .submitLabel(.continue)
                        .onSubmit { viewModel.advance() }

                    if let error = viewModel.nameError {
                        Text(error)
                            .sdtFont(.caption, color: .sdtHealthCritical)
                    }
                }

                if !viewModel.skillName.isEmpty || true {
                    VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                        Text("Suggestions")
                            .sdtFont(.captionSemibold, color: .sdtSecondary)

                        SkillSuggestionsView(query: viewModel.skillName) { suggestion in
                            viewModel.apply(suggestion: suggestion)
                            focused = false
                        }
                        .padding(SDTSpacing.md)
                        .background(Color.sdtSurface)
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
                    }
                }
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.top, SDTSpacing.xl)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Step 2: Category

private struct CategoryStepView: View {
    @Bindable var viewModel: AddSkillViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SDTSpacing.xl) {
                stepHeader(
                    icon: "tag",
                    title: "Pick a category",
                    subtitle: "This determines the accent colour and icon for your skill."
                )

                LazyVGrid(columns: columns, spacing: SDTSpacing.md) {
                    ForEach(SkillCategory.allCases, id: \.self) { category in
                        categoryCard(category)
                    }
                }
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.top, SDTSpacing.xl)
        }
    }

    private func categoryCard(_ category: SkillCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            viewModel.selectedCategory = category
        } label: {
            VStack(spacing: SDTSpacing.sm) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? .white : category.color)

                Text(category.rawValue)
                    .sdtFont(.bodySemibold, color: isSelected ? .white : .sdtPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.xl)
            .background(isSelected ? category.color : Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                        .strokeBorder(category.color.opacity(0.3), lineWidth: 1.5)
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isSelected)
        .animation(SDTAnimation.scoreChange, value: isSelected)
    }
}

// MARK: - Step 3: Difficulty

private struct DifficultyStepView: View {
    @Bindable var viewModel: AddSkillViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SDTSpacing.xl) {
                stepHeader(
                    icon: "slider.horizontal.3",
                    title: "How hard is it for you?",
                    subtitle: "This sets the initial practice frequency."
                )

                VStack(spacing: SDTSpacing.xl) {
                    // Visual difficulty indicator
                    HStack {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= Int(viewModel.initialDifficulty.rounded())
                                      ? viewModel.selectedCategory.color
                                      : Color.sdtSecondary.opacity(0.2))
                                .frame(width: 14, height: 14)
                                .animation(SDTAnimation.scoreChange, value: viewModel.initialDifficulty)
                            if level < 5 { Spacer() }
                        }
                    }
                    .padding(.horizontal, SDTSpacing.xl)

                    VStack(spacing: SDTSpacing.xs) {
                        Text(viewModel.difficultyLabel)
                            .sdtFont(.titleSmall, color: viewModel.selectedCategory.color)
                        Text(viewModel.difficultyDescription)
                            .sdtFont(.caption, color: .sdtSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Slider(
                        value: $viewModel.initialDifficulty,
                        in: 1...5,
                        step: 1
                    )
                    .tint(viewModel.selectedCategory.color)
                    .sensoryFeedback(.selection, trigger: viewModel.initialDifficulty)

                    HStack {
                        Text("Easy").sdtFont(.caption, color: .sdtSecondary)
                        Spacer()
                        Text("Hard").sdtFont(.caption, color: .sdtSecondary)
                    }
                }
                .padding(SDTSpacing.lg)
                .sdtCard()
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.top, SDTSpacing.xl)
        }
    }
}

// MARK: - Step 4: Confirm

private struct ConfirmStepView: View {
    let viewModel: AddSkillViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SDTSpacing.xl) {
                stepHeader(
                    icon: "checkmark.circle",
                    title: "Looks good?",
                    subtitle: "You can edit these settings later in Skill Detail."
                )

                VStack(spacing: SDTSpacing.md) {
                    summaryRow(
                        label: "Name",
                        value: viewModel.skillName,
                        icon: "pencil"
                    )
                    Divider()
                    summaryRow(
                        label: "Category",
                        value: viewModel.selectedCategory.rawValue,
                        icon: viewModel.selectedCategory.systemImage,
                        tint: viewModel.selectedCategory.color
                    )
                    Divider()
                    summaryRow(
                        label: "Difficulty",
                        value: viewModel.difficultyLabel,
                        icon: "slider.horizontal.3"
                    )
                    Divider()
                    summaryRow(
                        label: "Review cadence",
                        value: viewModel.difficultyDescription,
                        icon: "calendar"
                    )
                }
                .padding(SDTSpacing.lg)
                .sdtCard()

                Text("AI will generate 3 personalised challenges in the background.")
                    .sdtFont(.caption, color: .sdtSecondary)
                    .padding(.horizontal, SDTSpacing.xs)
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.top, SDTSpacing.xl)
        }
    }

    private func summaryRow(label: String, value: String,
                             icon: String, tint: Color = .sdtSecondary) -> some View {
        HStack(spacing: SDTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(label)
                .sdtFont(.bodyMedium, color: .sdtSecondary)

            Spacer()

            Text(value)
                .sdtFont(.bodySemibold)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Shared Step Header

private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: SDTSpacing.sm) {
        Image(systemName: icon)
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(Color.sdtPrimary)

        Text(title)
            .sdtFont(.titleMedium)

        Text(subtitle)
            .sdtFont(.bodyMedium, color: .sdtSecondary)
    }
}

// MARK: - Button Styles

private struct PrimaryButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sdtFont(.bodySemibold, color: .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.md)
            .background(tint.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
            .animation(SDTAnimation.scoreChange, value: configuration.isPressed)
    }
}

private struct BackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sdtFont(.bodySemibold, color: .sdtSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.md)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
    }
}

// MARK: - Preview

#Preview {
    AddSkillView()
        .modelContainer(for: [Skill.self, Challenge.self,
                               ChallengeResult.self, UserProfile.self],
                        inMemory: true)
}
