import SwiftUI
import SwiftData

/// Full-screen detail sheet for a single skill.
///
/// Sections:
/// 1. Hero — large health ring, score %, category chip, streak badge, "Start Practice" CTA
/// 2. Stats grid — 4 key metrics
/// 3. Decay Forecast — 30-day ``SDTDecayCurve`` chart
/// 4. Recent Challenges — last 5 completed challenges
struct SkillDetailView: View {

    let skill: Skill

    /// Optional callback invoked when the user taps "Start Practice".
    /// The sheet dismisses first, then the callback fires.
    var onStartPractice: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SkillGroup.name) private var groups: [SkillGroup]

    @State private var appeared = false
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SDTSpacing.xxl) {
                    heroSection
                    focusSection
                    statsGrid
                    decayCurveSection
                    recentChallengesSection
                }
                .padding(.horizontal, SDTSpacing.xl)
                .padding(.bottom, SDTSpacing.xxxl)
            }
            .background(Color.sdtBackground)
            .navigationTitle(skill.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showEditSheet) {
                EditSkillSheet(skill: skill)
            }
            .alert(
                "Delete \"\(skill.name)\"?",
                isPresented: $showDeleteConfirm
            ) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(skill)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All practice history will be permanently deleted.")
            }
        }
        .onAppear {
            withAnimation(SDTAnimation.scoreChange) { appeared = true }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit Skill", systemImage: "pencil")
                }

                Divider()

                // Move to group submenu
                if !groups.isEmpty {
                    Menu {
                        ForEach(groups) { group in
                            let alreadyIn = skill.group?.id == group.id
                            Button {
                                if alreadyIn {
                                    skill.group?.skills.removeAll { $0.id == skill.id }
                                    skill.group = nil
                                } else {
                                    skill.group?.skills.removeAll { $0.id == skill.id }
                                    skill.group = group
                                    if !group.skills.contains(where: { $0.id == skill.id }) {
                                        group.skills.append(skill)
                                    }
                                }
                                try? modelContext.save()
                            } label: {
                                Label(
                                    "\(group.emoji) \(group.name)",
                                    systemImage: alreadyIn ? "checkmark.circle.fill" : "folder"
                                )
                            }
                        }

                        if skill.group != nil {
                            Divider()
                            Button(role: .destructive) {
                                skill.group?.skills.removeAll { $0.id == skill.id }
                                skill.group = nil
                                try? modelContext.save()
                            } label: {
                                Label("Remove from Group", systemImage: "folder.badge.minus")
                            }
                        }
                    } label: {
                        Label(
                            skill.group.map { "\($0.emoji) \($0.name)" } ?? "Move to Group",
                            systemImage: "folder"
                        )
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Skill", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: SDTSpacing.lg) {
            // Large health ring
            ZStack {
                SDTHealthRing(score: skill.healthScore, lineWidth: 12)
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .animation(SDTAnimation.scoreChange, value: appeared)

                VStack(spacing: 1) {
                    Text("\(Int(skill.healthScore * 100))")
                        .sdtFont(.numericLarge, color: Color.sdtHealth(for: skill.healthScore))
                    Text("%")
                        .sdtFont(.captionSemibold, color: Color.sdtHealth(for: skill.healthScore))
                }
            }

            // Status labels
            VStack(spacing: SDTSpacing.sm) {
                Text(Color.sdtHealthLabel(for: skill.healthScore))
                    .sdtFont(.bodySemibold, color: Color.sdtHealth(for: skill.healthScore))

                HStack(spacing: SDTSpacing.sm) {
                    Label(skill.category.rawValue, systemImage: skill.category.systemImage)
                        .sdtFont(.captionSemibold)
                        .padding(.horizontal, SDTSpacing.md)
                        .padding(.vertical, SDTSpacing.xs)
                        .background(skill.category.color.opacity(0.15))
                        .foregroundStyle(skill.category.color)
                        .clipShape(Capsule())

                    if skill.streakDays > 0 {
                        SDTStreakBadge(days: skill.streakDays)
                    }
                }
            }

            // Start Practice button
            if let practice = onStartPractice {
                Button {
                    dismiss()
                    practice()
                } label: {
                    Label("Start Practice", systemImage: "play.fill")
                        .sdtFont(.bodySemibold, color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SDTSpacing.md)
                        .background(Color.sdtHealth(for: skill.healthScore))
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, SDTSpacing.lg)
    }

    // MARK: - Focus Section

    @ViewBuilder
    private var focusSection: some View {
        let ctx = skill.context.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            HStack {
                Label("Focus", systemImage: "scope")
                    .sdtFont(.bodySemibold)
                Spacer()
                Button {
                    showEditSheet = true
                } label: {
                    Text(ctx.isEmpty ? "Add" : "Edit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.sdtPrimary)
                }
            }

            if ctx.isEmpty {
                Text("No focus yet. Add a goal to get more targeted questions — e.g. \"IELTS B2 exam\", \"jazz improvisation\", \"organic chemistry\".")
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sdtCard()
            } else {
                Text(ctx)
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sdtCard()
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: SDTSpacing.md
        ) {
            statCard(
                value: "\(skill.totalPracticeCount)",
                label: "Challenges",
                icon: "checkmark.circle"
            )
            statCard(
                value: skill.accuracyRate.map { "\(Int($0 * 100))%" } ?? "—",
                label: "Accuracy",
                icon: "target"
            )
            statCard(
                value: "\(skill.streakDays)d",
                label: "Streak",
                icon: "flame"
            )
            statCard(
                value: nextReviewLabel,
                label: "Next Review",
                icon: "calendar"
            )
        }
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: SDTSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.sdtSecondary)
            Text(value)
                .sdtFont(.titleSmall)
            Text(label)
                .sdtFont(.caption, color: .sdtSecondary)
        }
        .frame(maxWidth: .infinity)
        .sdtCard()
    }

    // MARK: - Decay Curve Section

    private var decayCurveSection: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            Text("Decay Forecast")
                .sdtFont(.bodySemibold)

            SDTDecayCurve(skill: skill)
                .frame(height: 155)
                .sdtCard(padding: SDTSpacing.md)
        }
    }

    // MARK: - Recent Challenges Section

    @ViewBuilder
    private var recentChallengesSection: some View {
        let recent: [Challenge] = skill.challenges
            .filter { !$0.results.isEmpty }
            .sorted { lhs, rhs -> Bool in
                let lDate = lhs.results.max(by: { $0.practiceDate < $1.practiceDate })?.practiceDate ?? .distantPast
                let rDate = rhs.results.max(by: { $0.practiceDate < $1.practiceDate })?.practiceDate ?? .distantPast
                return lDate > rDate
            }
            .prefix(5)
            .map { $0 }

        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            Text("Recent Challenges")
                .sdtFont(.bodySemibold)

            if recent.isEmpty {
                Text("No challenges completed yet.")
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .sdtCard()
            } else {
                VStack(spacing: SDTSpacing.sm) {
                    ForEach(recent) { challenge in
                        recentRow(for: challenge)
                    }
                }
            }
        }
    }

    private func recentRow(for challenge: Challenge) -> some View {
        let lastResult = challenge.results.max(by: { $0.practiceDate < $1.practiceDate })
        let isCorrect  = lastResult?.isCorrect == true

        return HStack(spacing: SDTSpacing.md) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isCorrect ? Color.sdtHealthThriving : Color.sdtHealthCritical)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: SDTSpacing.xxs) {
                Text(challenge.question)
                    .sdtFont(.bodyMedium)
                    .lineLimit(2)
                Text(challenge.type.displayName)
                    .sdtFont(.caption, color: .sdtSecondary)
            }

            Spacer()

            if let date = lastResult?.practiceDate {
                Text(date.relativeString)
                    .sdtFont(.caption, color: .sdtSecondary)
            }
        }
        .sdtCard(padding: SDTSpacing.md)
    }

    // MARK: - Helpers

    private var nextReviewLabel: String {
        let now = Date.now
        guard skill.nextReviewDate > now else { return "Now" }
        let days = Int(skill.nextReviewDate.timeIntervalSince(now) / 86_400)
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "in \(days)d"
    }
}

// MARK: - Preview

#Preview {
    let skill = Skill(name: "SwiftUI", category: .programming, decayRate: 0.08)
    return SkillDetailView(skill: skill, onStartPractice: {})
}

// MARK: - EditSkillSheet

/// Sheet for editing skill name, category, and AI context.
private struct EditSkillSheet: View {

    let skill: Skill

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: SkillCategory
    @State private var context: String

    init(skill: Skill) {
        self.skill = skill
        _name     = State(initialValue: skill.name)
        _category = State(initialValue: skill.category)
        _context  = State(initialValue: skill.context)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Skill name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(SkillCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue.capitalized, systemImage: cat.systemImage)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Category")
                }

                Section {
                    TextField(
                        "e.g. \"IELTS B2 exam\", \"jazz improvisation\", \"organic chemistry\"",
                        text: $context,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .autocorrectionDisabled()
                } header: {
                    Text("Focus / Context")
                } footer: {
                    Text("AI uses this to generate more targeted questions. Leave empty for broad coverage.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.sdtBackground)
            .navigationTitle("Edit Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        skill.name     = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        skill.category = category
                        skill.context  = context.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}
