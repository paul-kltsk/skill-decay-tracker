import SwiftUI
import SwiftData

/// Tab 2 — Skill Map.
///
/// Toggles between two layouts via a floating pill at the bottom:
/// - **Constellation** — full-screen interactive star canvas (default)
/// - **Grid** — 2-column sortable/filterable card grid
///
/// Both layouts share ``SkillMapViewModel`` for selection state, filtering,
/// and sorting. Selecting a skill opens ``SkillDetailView`` as a sheet.
struct SkillMapView: View {

    @Query(sort: \Skill.healthScore) private var skills: [Skill]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var sub
    @State private var viewModel = SkillMapViewModel()
    @State private var showManageGroups = false
    @State private var showPaywall = false
    @State private var paywallTrigger: ProFeature = .generic
    @State private var practiceViewModel = PracticeViewModel()

    // MARK: - Body

    var body: some View {
        mainContent
        .background(Color.sdtBackground)
        .navigationTitle("Skill Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: SDTSpacing.sm) {
                    Button {
                        if sub.isPro {
                            showManageGroups = true
                        } else {
                            paywallTrigger = .skillGroups
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "folder.badge.gear")
                    }
                    Button {
                        if sub.canAddSkill(currentCount: skills.count) {
                            viewModel.showAddSkill = true
                        } else {
                            paywallTrigger = .skillLimit
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showManageGroups) {
            ManageGroupsView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallTrigger)
        }
        .sheet(isPresented: $viewModel.showAddSkill) {
            AddSkillView(
                onStartPractice: { newSkills, questionCount in
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
        .sheet(isPresented: $viewModel.showDetail) {
            if let skill = viewModel.selectedSkill {
                SkillDetailView(skill: skill, onStartPractice: {
                    viewModel.showDetail = false
                    Task {
                        await practiceViewModel.startSession(
                            mode: .deepDive(skillID: skill.id),
                            skills: [skill],
                            context: modelContext,
                            challengeCount: sub.effectiveQuestionCount(for: skill)
                        )
                    }
                })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            viewModel.refreshHealth(for: skills)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        gridContent
    }

    // MARK: - Grid Mode

    private var gridContent: some View {
        ScrollView {
            VStack(spacing: SDTSpacing.md) {
                filterBar
                    .padding(.horizontal, SDTSpacing.xl)

                if skills.isEmpty {
                    SDTEmptyState(
                        icon: "square.grid.2x2",
                        title: "No skills yet",
                        message: "Tap + to add your first skill.",
                        actionLabel: "Add Skill",
                        action: { viewModel.showAddSkill = true }
                    )
                } else {
                    SkillGridView(
                        skills: viewModel.filtered(skills),
                        viewModel: viewModel
                    )
                    .padding(.horizontal, SDTSpacing.xl)
                }
            }
            .padding(.top, SDTSpacing.lg)
        }
    }

    // MARK: - Filter Bar (Grid only)

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SDTSpacing.sm) {
                // Sort menu
                Menu {
                    ForEach(SkillSortOrder.allCases, id: \.rawValue) { order in
                        Button {
                            viewModel.sortOrder = order
                        } label: {
                            Label(order.displayName, systemImage: order.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: SDTSpacing.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(viewModel.sortOrder.displayName)
                    }
                    .sdtFont(.captionSemibold)
                    .padding(.horizontal, SDTSpacing.md)
                    .padding(.vertical, SDTSpacing.sm)
                    .background(Color.sdtSurface)
                    .clipShape(Capsule())
                }

                Divider()
                    .frame(height: 20)

                // Category filter chips
                ForEach(SkillCategory.allCases, id: \.rawValue) { category in
                    let selected = viewModel.selectedCategory == category
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedCategory = selected ? nil : category
                        }
                    } label: {
                        Label(category.displayName, systemImage: category.systemImage)
                            .sdtFont(.captionSemibold, color: selected ? .white : category.color)
                            .padding(.horizontal, SDTSpacing.md)
                            .padding(.vertical, SDTSpacing.sm)
                            .background(selected ? category.color : category.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

// MARK: - Preview

#Preview {
    NavigationStack { SkillMapView() }
}
