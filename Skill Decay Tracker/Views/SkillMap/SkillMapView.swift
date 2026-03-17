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
    @State private var viewModel = SkillMapViewModel()

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
            floatingModeToggle
                .padding(.bottom, SDTSpacing.sm)
        }
        .background(Color.sdtBackground)
        .navigationTitle("Skill Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showAddSkill = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddSkill) {
            AddSkillView()
        }
        .sheet(isPresented: $viewModel.showDetail) {
            if let skill = viewModel.selectedSkill {
                SkillDetailView(skill: skill)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .task {
            viewModel.refreshHealth(for: skills)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.viewMode {
        case .constellation:
            constellationContent

        case .grid:
            gridContent
        }
    }

    // MARK: - Constellation Mode

    private var constellationContent: some View {
        Group {
            if skills.isEmpty {
                SDTEmptyState(
                    icon: "sparkles",
                    title: "Your constellation is empty",
                    message: "Add your first skill to start tracking.",
                    actionLabel: "Add Skill",
                    action: { viewModel.showAddSkill = true }
                )
            } else {
                ConstellationView(
                    skills: viewModel.filtered(skills),
                    viewModel: viewModel
                )
            }
        }
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
            .padding(.bottom, 80) // clear floating toggle
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
                            Label(order.rawValue, systemImage: order.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: SDTSpacing.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(viewModel.sortOrder.rawValue)
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
                        Label(category.rawValue, systemImage: category.systemImage)
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

    // MARK: - Floating Mode Toggle

    private var floatingModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(MapViewMode.allCases, id: \.rawValue) { mode in
                let selected = viewModel.viewMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.viewMode = mode
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 17, weight: selected ? .semibold : .regular))
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selected ? Color.sdtPrimary : Color.sdtSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SDTSpacing.sm)
                    .background(selected ? Color.sdtBackground : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SDTSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                .fill(Color.sdtSurface.opacity(0.94))
                .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 4)
        )
        .padding(.horizontal, SDTSpacing.xxl)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { SkillMapView() }
}
