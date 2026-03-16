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

    @State private var appeared = false
    @State private var showDeleteConfirm = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SDTSpacing.xxl) {
                    heroSection
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
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
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
