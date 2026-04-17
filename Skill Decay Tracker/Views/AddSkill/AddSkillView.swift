import SwiftUI
import SwiftData

/// A 5-step modal wizard for adding a new skill to the portfolio.
///
/// Steps: **Name → Category → Difficulty → Question Count → Confirm**
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

    var onSkillCreated: (([Skill]) -> Void)? = nil

    /// Fired after save; the sheet dismisses first, then this callback runs.
    /// Parameters: created skills + the question count chosen by the user.
    var onStartPractice: (([Skill], Int) -> Void)? = nil

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
                    QuestionCountStepView(viewModel: viewModel)
                        .tag(3)
                    ConfirmStepView(viewModel: viewModel)
                        .tag(4)
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
            .task(id: viewModel.currentStep) {
                guard viewModel.currentStep == 3 else { return }
                viewModel.startBaselinePrefetch()
            }
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
            ForEach(0..<5, id: \.self) { step in
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
        if viewModel.currentStep == 4 {
            // Confirm step — two actions
            VStack(spacing: SDTSpacing.sm) {
                Button {
                    let skills = viewModel.saveAll(context: modelContext)
                    onSkillCreated?(skills)
                    dismiss()
                    onStartPractice?(skills, viewModel.selectedQuestionCount)
                } label: {
                    if viewModel.isPrefetchingChallenges {
                        HStack(spacing: SDTSpacing.sm) {
                            ProgressView()
                                .scaleEffect(0.85)
                                .tint(.white)
                            Text("Generating questions…")
                        }
                    } else {
                        Label("Start Practice", systemImage: "play.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: viewModel.selectedCategory.color))
                .disabled(viewModel.isPrefetchingChallenges)

                Button("Save & Continue") {
                    let skills = viewModel.saveAll(context: modelContext)
                    onSkillCreated?(skills)
                    dismiss()
                }
                .buttonStyle(BackButtonStyle())
            }

        } else if viewModel.currentStep == 0 {
            Button {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                viewModel.advance()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle(tint: viewModel.selectedCategory.color))
            .disabled(!viewModel.isNameValid)

        } else {
            HStack(spacing: SDTSpacing.md) {
                Button("Back") { viewModel.back() }
                    .buttonStyle(BackButtonStyle())

                Button("Continue") { viewModel.advance() }
                    .buttonStyle(PrimaryButtonStyle(tint: viewModel.selectedCategory.color))
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
                        .onSubmit { nameFocused = false }
                        .onChange(of: viewModel.skillName) { _, _ in
                            // Clear stale chips immediately; analysis fires on blur, not per-keystroke
                            viewModel.clearFocusSuggestions()
                        }

                    if let error = viewModel.nameError {
                        Text(error)
                            .sdtFont(.caption, color: .sdtHealthCritical)
                    }
                }

                // Context / focus field
                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    Text("Focus or goal")
                        .sdtFont(.captionSemibold, color: .sdtSecondary)
                    TextField("e.g. DELF B2 exam, Jazz improvisation, Organic chemistry…",
                              text: $viewModel.skillContext)
                        .sdtFont(.bodyMedium)
                        .padding(SDTSpacing.md)
                        .background(Color.sdtSurface)
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                        .submitLabel(.done)
                }

                // AI analysis banner (shown while check is in flight)
                if viewModel.isAnalyzingFocus {
                    analyzingBanner
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Focus suggestions (shown after AI check finds a broad topic)
                focusSuggestionsSection
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.top, SDTSpacing.xl)
        }
        .onAppear { nameFocused = true }
        .onChange(of: nameFocused) { _, isFocused in
            // Fire analysis when user leaves the name field — not on every keystroke
            if !isFocused { viewModel.analyzeNameIfNeeded() }
        }
        .animation(SDTAnimation.scoreChange, value: viewModel.isAnalyzingFocus)
        .animation(SDTAnimation.scoreChange, value: viewModel.focusSuggestions.isEmpty)
    }

    // MARK: Analyzing Banner

    private var analyzingBanner: some View {
        HStack(spacing: SDTSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(Color.sdtCategoryProgramming)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI is exploring focused directions…")
                    .sdtFont(.captionSemibold)
                Text("We'll suggest a more specific goal if it makes sense")
                    .sdtFont(.caption, color: .sdtSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SDTSpacing.md)
        .padding(.vertical, SDTSpacing.sm)
        .background(Color.sdtCategoryProgramming.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                .strokeBorder(Color.sdtCategoryProgramming.opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: Focus Suggestions Section

    @ViewBuilder
    private var focusSuggestionsSection: some View {
        if !viewModel.focusSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: SDTSpacing.md) {
                HStack(spacing: SDTSpacing.xs) {
                    Image(systemName: "scope")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.sdtCategoryProgramming)
                    Text("AI suggests a more focused direction")
                        .sdtFont(.captionSemibold, color: .sdtSecondary)
                }

                Text("Tap a suggestion to use it as your focus goal, or write your own in the field above.")
                    .sdtFont(.caption, color: .sdtSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlexRow(spacing: SDTSpacing.sm) {
                    ForEach(viewModel.focusSuggestions) { suggestion in
                        let isSel = viewModel.skillContext
                            .trimmingCharacters(in: .whitespacesAndNewlines) == suggestion.name
                        FocusChip(suggestion: suggestion, isSelected: isSel) {
                            withAnimation(SDTAnimation.scoreChange) {
                                if isSel {
                                    viewModel.skillContext = ""
                                } else {
                                    viewModel.skillContext = suggestion.name
                                }
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

// MARK: - Focus Chip

private struct FocusChip: View {
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
            .foregroundStyle(isSelected ? .white : Color.sdtCategoryProgramming)
            .padding(.horizontal, SDTSpacing.md)
            .padding(.vertical, SDTSpacing.xs)
            .background(isSelected ? Color.sdtCategoryProgramming : Color.sdtSurface)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(Color.sdtCategoryProgramming.opacity(0.4), lineWidth: 1)
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

                Text(category.displayName)
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

// MARK: - Step 3: Question Count

private struct QuestionCountStepView: View {
    @Bindable var viewModel: AddSkillViewModel
    @Environment(SubscriptionService.self) private var sub
    @State private var showPaywall = false

    private var isPro: Bool { sub.isPro }
    private let options = [5, 7, 10, 15]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SDTSpacing.xl) {
                stepHeader(
                    icon: "list.number",
                    title: "How many questions?",
                    subtitle: "Choose how many challenges to tackle per session."
                )

                VStack(spacing: SDTSpacing.sm) {
                    ForEach(options, id: \.self) { count in
                        let isLocked  = !isPro && count > 5
                        let isSelected = viewModel.selectedQuestionCount == count

                        Button {
                            if isLocked {
                                showPaywall = true
                            } else {
                                viewModel.selectedQuestionCount = count
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: SDTSpacing.xxs) {
                                    Text("\(count) questions")
                                        .sdtFont(.bodySemibold,
                                                 color: isSelected ? .white
                                                      : isLocked   ? .sdtSecondary
                                                                   : .sdtPrimary)
                                    Text(descriptionFor(count))
                                        .sdtFont(.caption,
                                                 color: isSelected ? .white.opacity(0.8) : .sdtSecondary)
                                }
                                Spacer()
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.sdtSecondary)
                                } else if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(SDTSpacing.md)
                            .background(isSelected ? viewModel.selectedCategory.color : Color.sdtSurface)
                            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
                            .overlay {
                                if !isSelected {
                                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                                        .strokeBorder(
                                            isLocked
                                                ? Color.sdtSecondary.opacity(0.15)
                                                : viewModel.selectedCategory.color.opacity(0.3),
                                            lineWidth: 1.5
                                        )
                                }
                            }
                            .opacity(isLocked ? 0.55 : 1)
                            .contentShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
                        }
                        .buttonStyle(.plain)
                        .animation(SDTAnimation.scoreChange, value: isSelected)
                        .sensoryFeedback(.impact(flexibility: .soft), trigger: isSelected)
                    }

                    if !isPro {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: SDTSpacing.xs) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.sdtPrimary)
                                Text("Unlock up to 15 questions per session with Pro")
                                    .sdtFont(.caption, color: .sdtSecondary)
                            }
                            .padding(SDTSpacing.sm)
                            .background(Color.sdtPrimary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.top, SDTSpacing.xl)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: .questionCount)
        }
    }

    private func descriptionFor(_ count: Int) -> String {
        switch count {
        case 5:  return String(localized: "Quick session · ~5 min")
        case 7:  return String(localized: "Balanced session · ~8 min")
        case 10: return String(localized: "Standard session · ~12 min")
        case 15: return String(localized: "Deep dive · ~18 min")
        default: return ""
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

                singleConfirm
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
                           value: viewModel.selectedCategory.displayName,
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

            prefetchStatusLabel
                .padding(.horizontal, SDTSpacing.xs)
                .padding(.top, SDTSpacing.md)
        }
    }

    /// Reflects the background challenge pre-generation state.
    private var prefetchStatusLabel: some View {
        Group {
            if viewModel.isPrefetchingChallenges {
                HStack(spacing: SDTSpacing.xs) {
                    ProgressView().scaleEffect(0.7)
                    Text("Preparing personalised questions…")
                        .sdtFont(.caption, color: .sdtSecondary)
                }
            } else if !viewModel.prefetchedChallenges.isEmpty {
                HStack(spacing: SDTSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sdtHealthHealthy)
                        .font(.system(size: 12))
                    Text("\(viewModel.prefetchedChallenges.count) questions ready — practice starts instantly.")
                        .sdtFont(.caption, color: .sdtHealthHealthy)
                }
            } else {
                Text("AI will generate 5 personalised challenges in the background.")
                    .sdtFont(.caption, color: .sdtSecondary)
            }
        }
    }

    private func summaryRow(label: LocalizedStringKey, value: String,
                             icon: String, tint: Color = .sdtSecondary) -> some View {
        HStack(spacing: SDTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(label)
                .sdtFont(.bodyMedium, color: .sdtSecondary)

            Spacer()

            Text(verbatim: value)
                .sdtFont(.bodySemibold)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Shared Step Header

private func stepHeader(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
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
