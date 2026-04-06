import SwiftUI
import SwiftData

/// Practice tab root — lets the user pick Daily Review, Quick Practice, or Deep Dive.
struct SessionLauncherView: View {

    @Query(sort: \Skill.healthScore) private var skills: [Skill]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var sub
    @State private var viewModel = PracticeViewModel()
    @State private var showDeepDivePicker = false
    @State private var showPaywall = false
    @State private var paywallTrigger: ProFeature = .generic

    var body: some View {
        ScrollView {
            VStack(spacing: SDTSpacing.xl) {
                statsRow
                    .padding(.top, SDTSpacing.sm)

                VStack(spacing: SDTSpacing.md) {
                    modeCard(
                        title: "Daily Review",
                        subtitle: "All overdue skills · \(overdueCount) due today",
                        icon: "calendar.badge.clock",
                        tint: .sdtCategoryProgramming,
                        disabled: overdueCount == 0
                    ) {
                        startSession(.dailyReview)
                    }

                    modeCard(
                        title: "Quick Practice",
                        subtitle: skills.isEmpty ? "Add skills to get started" : "5 challenges · \(skills.first.map { "\($0.name)" } ?? "")",
                        icon: "bolt.fill",
                        tint: .sdtCategoryTool,
                        disabled: skills.isEmpty,
                        requiresPro: !sub.isPro
                    ) {
                        if sub.isPro {
                            startSession(.quickPractice)
                        } else {
                            paywallTrigger = .quickPractice
                            showPaywall = true
                        }
                    }

                    modeCard(
                        title: "Deep Dive",
                        subtitle: "All pending challenges for one skill",
                        icon: "scope",
                        tint: .sdtCategoryConcept,
                        disabled: skills.isEmpty,
                        requiresPro: !sub.isPro
                    ) {
                        if sub.isPro {
                            showDeepDivePicker = true
                        } else {
                            paywallTrigger = .deepDive
                            showPaywall = true
                        }
                    }
                }

                if case .error(let msg) = viewModel.phase {
                    VStack(spacing: SDTSpacing.sm) {
                        Text(msg)
                            .sdtFont(.caption, color: .sdtHealthCritical)
                            .multilineTextAlignment(.center)
                        Button("Dismiss") { viewModel.endSession() }
                            .sdtFont(.captionSemibold, color: .sdtSecondary)
                    }
                    .padding(.horizontal, SDTSpacing.lg)
                }
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.bottom, SDTSpacing.xxxl)
        }
        .background(Color.sdtBackground)
        .navigationTitle("Practice")
        .fullScreenCover(isPresented: $viewModel.isSessionActive) {
            ChallengeView(viewModel: viewModel)
        }
        .sheet(isPresented: $showDeepDivePicker) {
            deepDivePicker
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallTrigger)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: SDTSpacing.md) {
            statBadge(value: "\(skills.count)", label: "Skills")
            Divider().frame(height: 32)
            statBadge(value: "\(overdueCount)", label: "Due")
            Divider().frame(height: 32)
            statBadge(
                value: "\(skills.map(\.streakDays).max() ?? 0)",
                label: "Best streak"
            )
        }
        .padding(SDTSpacing.md)
        .sdtCard()
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: SDTSpacing.xxs) {
            Text(value).sdtFont(.numericMedium)
            Text(label).sdtFont(.caption, color: .sdtSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mode Card

    private func modeCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        disabled: Bool,
        requiresPro: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SDTSpacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(disabled ? .sdtSecondary : tint)
                    .frame(width: 44, height: 44)
                    .background((disabled ? Color.sdtSecondary : tint).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))

                VStack(alignment: .leading, spacing: SDTSpacing.xxs) {
                    HStack(spacing: SDTSpacing.xs) {
                        Text(title)
                            .sdtFont(.bodySemibold,
                                     color: disabled ? .sdtSecondary : .sdtPrimary)
                        if requiresPro {
                            ProBadgeLabel()
                        }
                    }
                    Text(subtitle)
                        .sdtFont(.caption, color: .sdtSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: requiresPro ? "lock.fill" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(disabled ? Color.sdtSecondary.opacity(0.4) : Color.sdtSecondary)
            }
            .padding(SDTSpacing.lg)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .shadow(color: .black.opacity(disabled ? 0 : 0.05), radius: 6, x: 0, y: 2)
        }
        .disabled(disabled || viewModel.phase == .loading)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: disabled)
    }

    // MARK: - Deep Dive Picker Sheet

    private var deepDivePicker: some View {
        let practiceableSkills = skills.filter { !sub.isSkillLocked($0, allSkills: skills) }
        return NavigationStack {
            List(practiceableSkills) { skill in
                Button {
                    showDeepDivePicker = false
                    Task {
                        await viewModel.startSession(
                            mode: .deepDive(skillID: skill.id),
                            skills: practiceableSkills,
                            context: modelContext,
                            challengeCount: sub.effectiveQuestionCount(for: skill)
                        )
                    }
                } label: {
                    HStack(spacing: SDTSpacing.md) {
                        SDTHealthRing(score: skill.healthScore, lineWidth: 4)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: skill.category.systemImage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(skill.category.color)
                            }

                        VStack(alignment: .leading, spacing: SDTSpacing.xxs) {
                            Text(skill.name).sdtFont(.bodySemibold)
                            Text("\(skill.pendingChallenges.count) pending")
                                .sdtFont(.caption, color: .sdtSecondary)
                        }

                        Spacer()

                        Text("\(Int(skill.healthScore * 100))%")
                            .sdtFont(.captionSemibold,
                                     color: Color.sdtHealth(for: skill.healthScore))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Choose a Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showDeepDivePicker = false }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Skills the current user can practice (locked skills excluded for free tier).
    private var practiceableSkills: [Skill] {
        skills.filter { !sub.isSkillLocked($0, allSkills: skills) }
    }

    private var overdueCount: Int {
        practiceableSkills.filter { $0.nextReviewDate <= Date.now }.count
    }

    private func startSession(_ mode: SessionMode) {
        Task {
            await viewModel.startSession(mode: mode, skills: practiceableSkills, context: modelContext)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { SessionLauncherView() }
        .modelContainer(for: [Skill.self, Challenge.self,
                               ChallengeResult.self, UserProfile.self],
                        inMemory: true)
}
