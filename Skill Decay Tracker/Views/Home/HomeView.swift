import SwiftUI
import SwiftData

/// The app's landing tab — daily briefing, skill list sorted by urgency.
struct HomeView: View {

    // MARK: - Dependencies

    @Query(sort: \Skill.healthScore) private var skills: [Skill]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()

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
            AddSkillView { newSkill in
                viewModel.prefetchChallenges(for: newSkill, context: modelContext)
            }
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
        }
    }

    // MARK: - Subviews

    private var briefingCard: some View {
        DailyBriefingCard(
            portfolioHealth: viewModel.portfolioHealth(for: skills),
            overdueCount:    viewModel.overdueSkills(from: skills).count,
            topStreakDays:   skills.map(\.streakDays).max() ?? 0
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
            SDTSkillCard(skill: skill)
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
                viewModel.showAddSkill = true
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
