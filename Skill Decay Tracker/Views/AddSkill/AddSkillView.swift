import SwiftUI
import SwiftData

/// A 4-step modal wizard for adding a new skill to the portfolio.
///
/// Steps: **Name → Category → Difficulty → Confirm**
/// When the user selects AI-suggested sub-skills the Category step is skipped;
/// each sub-skill receives the AI-assigned category.
///
/// ```swift
/// .sheet(isPresented: $show) {
///     AddSkillView { newSkills in
///         newSkills.forEach { prefetchChallenges(for: $0) }
///     }
/// }
/// ```
struct AddSkillView: View {

    // MARK: - Dependencies

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddSkillViewModel()

    /// Called with every newly created skill after the user taps "Add Skill".
    var onSkillCreated: (([Skill]) -> Void)? = nil

    /// Optional callback to start a practice session immediately after saving.
    /// The sheet dismisses first, then the callback fires.
    var onStartPractice: (([Skill]) -> Void)? = nil

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

    @ViewBuilder
    private var navigationButtons: some View {
        if viewModel.currentStep == 3 {
            VStack(spacing: SDTSpacing.sm) {
                Button {
                    let skills = viewModel.saveAll(context: modelContext)
                    onSkillCreated?(skills)
                    dismiss()
                    onStartPractice?(skills)
                } label: {
                    Label("Start Practice", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(tint: viewModel.selectedCategory.color))

                Button("Save & Continue") {
                    let skills = viewModel.saveAll(context: modelContext)
                    onSkillCreated?(skills)
                    dismiss()
                }
                .buttonStyle(BackButtonStyle())
            }
        } else {
            HStack(spacing: SDTSpacing.md) {
                if viewModel.currentStep > 0 {
                    Button("Back") { viewModel.back() }
                        .buttonStyle(BackButtonStyle())
                }

                Button("Continue") { viewModel.advance() }
                    .buttonStyle(PrimaryButtonStyle(tint: viewModel.selectedCategory.color))
                    .disabled(!viewModel.canAdvance && viewModel.currentStep == 0)
            }
        }
    }
}

// MARK: - Step 1: Name

private struct NameStepView: View {
    @Bindable var viewModel: AddSkillViewModel
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SDTSpacing.xl) {
                stepHeader(
                    icon: "pencil",
                    title: "What are you learning?",
                    subtitle: "Give your skill a clear, specific name."
                )

                // Name field
                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    TextField("e.g. Spanish, Guitar, Chemistry…", text: $viewModel.skillName)
                        .sdtFont(.bodyLarge)
                        .padding(SDTSpacing.md)
                        .background(Color.sdtSurface)
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                        .focused($nameFocused)
                        .submitLabel(.next)
                        .onChange(of: viewModel.skillName) { _, _ in
                            viewModel.scheduleAnalysis()
                        }
                        .onSubmit { nameFocused = false }

                    if let error = viewModel.nameError {
                        Text(error)
                            .sdtFont(.caption, color: .sdtHealthCritical)
                    }
                }

                // Context field
                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    Text("Goal or context")
                        .sdtFont(.captionSemibold, color: .sdtSecondary)
                    TextField("e.g. DELF B2 exam, Jazz improvisation, Organic chemistry…",
                              text: $viewModel.skillContext)
                        .sdtFont(.bodyMedium)
                        .padding(SDTSpacing.md)
                        .background(Color.sdtSurface)
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                        .submitLabel(.done)
                }

                // Sub-skill suggestions
                subSkillSection

                // Curated suggestions
                if !viewModel.skillName.isEmpty || true {
                    VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                        Text("Suggestions")
                            .sdtFont(.captionSemibold, color: .sdtSecondary)

                        SkillSuggestionsView(query: viewModel.skillName) { suggestion in
                            viewModel.apply(suggestion: suggestion)
                            nameFocused = false
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
        .onAppear { nameFocused = true }
    }

    // MARK: Sub-Skill Section

    @ViewBuilder
    private var subSkillSection: some View {
        if viewModel.isAnalyzingSubSkills {
            HStack(spacing: SDTSpacing.sm) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Analysing skill scope…")
                    .sdtFont(.caption, color: .sdtSecondary)
            }
        } else if !viewModel.subSkillSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: SDTSpacing.md) {
                HStack(spacing: SDTSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.sdtCategoryProgramming)
                    Text("Split into sub-skills")
                        .sdtFont(.captionSemibold, color: .sdtSecondary)
                }

                Text("This topic covers multiple areas. Select the ones you want to track separately.")
                    .sdtFont(.caption, color: .sdtSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlexRow(spacing: SDTSpacing.sm) {
                    ForEach(viewModel.subSkillSuggestions) { suggestion in
                        SubSkillChip(
                            suggestion: suggestion,
                            isSelected: viewModel.selectedSubSkillIDs.contains(suggestion.id)
                        ) {
                            withAnimation(SDTAnimation.scoreChange) {
                                viewModel.toggleSubSkill(suggestion)
                            }
                        }
                    }
                }
            }
            .padding(SDTSpacing.md)
            .background(Color.sdtCategoryProgramming.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                    .strokeBorder(Color.sdtCategoryProgramming.opacity(0.2), lineWidth: 1)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Sub-Skill Chip

private struct SubSkillChip: View {
    let suggestion: SkillSuggestion
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(suggestion.name)
                    .sdtFont(.captionSemibold)
            }
            .foregroundStyle(isSelected ? .white : Color.sdtPrimary)
            .padding(.horizontal, SDTSpacing.md)
            .padding(.vertical, SDTSpacing.xs)
            .background(isSelected
                        ? suggestion.category.color
                        : Color.sdtSurface)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(suggestion.category.color.opacity(0.4), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isSelected)
    }
}

// MARK: - Flex Row Layout

/// A left-aligned wrapping layout for chips.
private struct FlexRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
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

                    Slider(value: $viewModel.initialDifficulty, in: 1...5, step: 1)
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

                if viewModel.isSplitting {
                    splittingConfirm
                } else {
                    singleConfirm
                }
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.top, SDTSpacing.xl)
        }
    }

    // MARK: Single skill confirm

    private var singleConfirm: some View {
        VStack(spacing: 0) {
            VStack(spacing: SDTSpacing.md) {
                summaryRow(label: "Name",
                           value: viewModel.skillName,
                           icon: "pencil")
                Divider()
                summaryRow(label: "Category",
                           value: viewModel.selectedCategory.rawValue,
                           icon: viewModel.selectedCategory.systemImage,
                           tint: viewModel.selectedCategory.color)
                Divider()
                summaryRow(label: "Difficulty",
                           value: viewModel.difficultyLabel,
                           icon: "slider.horizontal.3")
                Divider()
                summaryRow(label: "Review cadence",
                           value: viewModel.difficultyDescription,
                           icon: "calendar")

                if !viewModel.skillContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()
                    summaryRow(label: "Context",
                               value: viewModel.skillContext.trimmingCharacters(in: .whitespacesAndNewlines),
                               icon: "text.quote")
                }
            }
            .padding(SDTSpacing.lg)
            .sdtCard()

            Text("AI will generate 3 personalised challenges in the background.")
                .sdtFont(.caption, color: .sdtSecondary)
                .padding(.horizontal, SDTSpacing.xs)
                .padding(.top, SDTSpacing.md)
        }
    }

    // MARK: Sub-skill splitting confirm

    private var splittingConfirm: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            // Skills to create
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.selectedSubSkills.enumerated()), id: \.element.id) { index, sub in
                    HStack(spacing: SDTSpacing.md) {
                        Image(systemName: sub.category.systemImage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(sub.category.color)
                            .frame(width: 24)

                        Text(sub.name)
                            .sdtFont(.bodySemibold)

                        Spacer()

                        Text(sub.category.rawValue)
                            .sdtFont(.caption, color: .sdtSecondary)
                    }
                    .padding(SDTSpacing.md)

                    if index < viewModel.selectedSubSkills.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .sdtCard()

            // Shared settings row
            HStack(spacing: SDTSpacing.md) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.sdtSecondary)
                    .frame(width: 24)
                Text("All starting at")
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
                Spacer()
                Text(viewModel.difficultyLabel)
                    .sdtFont(.bodySemibold)
            }
            .padding(SDTSpacing.md)
            .sdtCard()

            if !viewModel.skillContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: SDTSpacing.md) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.sdtSecondary)
                        .frame(width: 24)
                    Text(viewModel.skillContext.trimmingCharacters(in: .whitespacesAndNewlines))
                        .sdtFont(.bodyMedium, color: .sdtSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SDTSpacing.md)
                .sdtCard()
            }

            Text("AI will generate personalised challenges for each skill in the background.")
                .sdtFont(.caption, color: .sdtSecondary)
                .padding(.horizontal, SDTSpacing.xs)
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
