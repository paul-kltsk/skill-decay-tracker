import SwiftUI
import SwiftData

/// The app's landing tab — daily briefing, skill list sorted by urgency.
struct HomeView: View {

    // MARK: - Dependencies

    @Query(sort: \Skill.healthScore) private var skills: [Skill]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionService.self) private var sub
    @State private var viewModel = HomeViewModel()
    @State private var showPaywall = false
    @State private var practiceViewModel = PracticeViewModel()

    /// Mirrors `NotificationSettingsView`'s threshold key so both screens
    /// read and write the same value without coupling to UserPreferences.
    @AppStorage("criticalAlertThreshold") private var criticalThreshold: Double = 0.30

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SDTSpacing.md) {
                briefingCard

                if skills.isEmpty {
                    emptyState
                } else {
                    skillList
                }
            }
            .padding(.horizontal, SDTSpacing.lg)
            .padding(.bottom, SDTSpacing.xxxl)
        }
        .background(Color.sdtBackground)
        .navigationTitle(viewModel.greeting)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { addButton }
        .sheet(isPresented: $viewModel.showAddSkill) {
            AddSkillView(
                onSkillCreated: { newSkills in
                    for skill in newSkills {
                        viewModel.prefetchChallenges(for: skill, context: modelContext)
                    }
                },
                onStartPractice: { newSkills, questionCount in
                    // Challenges were pre-generated during skill creation —
                    // start the session directly without an extra AI round-trip.
                    guard let first = newSkills.first else { return }
                    Task {
                        await practiceViewModel.startSession(
                            mode: .deepDive(skillID: first.id),
                            skills: newSkills,
                            context: modelContext,
                            challengeCount: questionCount
                        )
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $practiceViewModel.isSessionActive) {
            ChallengeView(viewModel: practiceViewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: .skillLimit)
        }
        .alert("Delete Skill", isPresented: Binding(
            get: { viewModel.skillPendingDelete != nil },
            set: { if !$0 { viewModel.skillPendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let skill = viewModel.skillPendingDelete {
                Text("\"\(skill.name)\" and all its history will be permanently deleted.")
            }
        }
        .task {
            viewModel.refreshHealth(for: skills)
            await syncNotifications()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshHealth(for: skills)
            Task { await syncNotifications() }
        }
    }

    // MARK: - Notification Sync

    /// Updates the badge, syncs the daily reminder, and schedules/cancels
    /// per-skill decay alerts based on the current health scores.
    private func syncNotifications() async {
        let prefs   = profiles.first?.preferences
        let enabled = prefs?.notificationsEnabled ?? false
        let hour    = prefs?.preferredPracticeTime?.hour   ?? 9
        let minute  = prefs?.preferredPracticeTime?.minute ?? 0

        await NotificationService.shared.syncDailyReminder(
            enabled: enabled, hour: hour, minute: minute)

        let overdue = skills.filter { $0.nextReviewDate <= Date.now }.count
        await NotificationService.shared.setBadgeCount(overdue)

        for skill in skills {
            if skill.healthScore <= criticalThreshold {
                await NotificationService.shared.scheduleCriticalAlert(
                    skillID: skill.id, skillName: skill.name)
            } else {
                await NotificationService.shared.cancelCriticalAlert(for: skill.id)
            }
        }
    }

    // MARK: - Subviews

    private var briefingCard: some View {
        DailyBriefingCard(
            portfolioHealth: viewModel.portfolioHealth(for: skills),
            overdueCount:    viewModel.overdueSkills(from: skills).count,
            topStreakDays:   skills.map(\.streakDays).max() ?? 0,
            onStartReview: {
                let overdue = viewModel.overdueSkills(from: skills)
                guard !overdue.isEmpty else { return }
                Task {
                    await practiceViewModel.startSession(
                        mode: .dailyReview,
                        skills: overdue,
                        context: modelContext
                    )
                }
            }
        )
        .padding(.top, SDTSpacing.sm)
    }

    private var emptyState: some View {
        SDTEmptyState(
            icon: "sparkles",
            title: "No Skills Yet",
            message: "Add your first skill and start tracking your knowledge portfolio.",
            actionLabel: "Add a Skill"
        ) {
            viewModel.showAddSkill = true
        }
        .padding(.top, SDTSpacing.xxl)
    }

    private var skillList: some View {
        ForEach(viewModel.sortedByUrgency(skills)) { skill in
            NavigationLink {
                SkillDetailView(skill: skill, onStartPractice: {
                    Task {
                        await practiceViewModel.startSession(
                            mode: .deepDive(skillID: skill.id),
                            skills: [skill],
                            context: modelContext
                        )
                    }
                })
            } label: {
                SDTSkillCard(skill: skill)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    viewModel.skillPendingDelete = skill
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if sub.canAddSkill(currentCount: skills.count) {
                    viewModel.showAddSkill = true
                } else {
                    showPaywall = true
                }
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
            .minTapTarget()
            .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.showAddSkill)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { HomeView() }
        .modelContainer(for: [Skill.self, Challenge.self,
                               ChallengeResult.self, UserProfile.self],
                        inMemory: true)
}
