import SwiftUI
import SwiftData

/// 2-column grid view of all skills, grouped by ``SkillGroup``.
///
/// Layout:
/// - Each group is rendered as a labelled section (emoji + name header).
/// - Ungrouped skills appear at the bottom under "Other" (hidden when no groups exist).
/// - Long-pressing any skill card shows a context menu to move it between groups.
struct SkillGridView: View {

    let skills: [Skill]
    let viewModel: SkillMapViewModel

    @Query(sort: \SkillGroup.name) private var groups: [SkillGroup]
    /// All skills (unfiltered) — needed to compute the free-tier set correctly.
    @Query private var allSkills: [Skill]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var sub

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    // MARK: - Body

    var body: some View {
        if skills.isEmpty {
            SDTEmptyState(
                icon: "square.grid.2x2",
                title: "No skills match",
                message: "Try a different filter or add your first skill."
            )
            .padding(.top, SDTSpacing.xxl)
        } else {
            LazyVStack(alignment: .leading, spacing: SDTSpacing.lg) {
                // Grouped sections
                ForEach(groups) { group in
                    let groupSkills = skills.filter { $0.group?.id == group.id }
                    if !groupSkills.isEmpty {
                        groupSection(group: group, skills: groupSkills)
                    }
                }

                // Ungrouped skills
                let ungrouped = skills.filter { $0.group == nil }
                if !ungrouped.isEmpty {
                    ungroupedSection(skills: ungrouped)
                }
            }
        }
    }

    // MARK: - Group Section

    private func groupSection(group: SkillGroup, skills: [Skill]) -> some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            // Section header
            HStack(spacing: SDTSpacing.xs) {
                Text(group.emoji)
                    .font(.system(size: 18))
                Text(group.name)
                    .sdtFont(.bodySemibold)
                Spacer()
                Text("\(skills.count)")
                    .sdtFont(.caption, color: .sdtSecondary)
                    .padding(.horizontal, SDTSpacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.sdtSurface)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, SDTSpacing.xs)

            LazyVGrid(columns: columns, spacing: SDTSpacing.md) {
                ForEach(skills) { skill in
                    let locked = sub.isSkillLocked(skill, allSkills: allSkills)
                    GridCard(
                        skill: skill,
                        isLocked: locked,
                        allGroups: groups,
                        onTap: { viewModel.select(skill) },
                        onMove: { target in move(skill: skill, to: target) },
                        onRemoveFromGroup: { removeFromGroup(skill: skill) }
                    )
                }
            }
        }
    }

    // MARK: - Ungrouped Section

    private func ungroupedSection(skills: [Skill]) -> some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            if !groups.isEmpty {
                Text("Other")
                    .sdtFont(.captionSemibold, color: .sdtSecondary)
                    .padding(.horizontal, SDTSpacing.xs)
            }

            LazyVGrid(columns: columns, spacing: SDTSpacing.md) {
                ForEach(skills) { skill in
                    let locked = sub.isSkillLocked(skill, allSkills: allSkills)
                    GridCard(
                        skill: skill,
                        isLocked: locked,
                        allGroups: groups,
                        onTap: { viewModel.select(skill) },
                        onMove: { target in move(skill: skill, to: target) },
                        onRemoveFromGroup: nil   // already ungrouped
                    )
                }
            }
        }
    }

    // MARK: - Group Mutations

    private func move(skill: Skill, to group: SkillGroup) {
        skill.group = group
        if !(group.skills ?? []).contains(where: { $0.id == skill.id }) {
            group.skills = (group.skills ?? []) + [skill]
        }
        try? modelContext.save()
    }

    private func removeFromGroup(skill: Skill) {
        skill.group?.skills?.removeAll { $0.id == skill.id }
        skill.group = nil
        try? modelContext.save()
    }
}

// MARK: - GridCard

private struct GridCard: View {

    let skill: Skill
    let isLocked: Bool
    let allGroups: [SkillGroup]
    let onTap: () -> Void
    let onMove: (SkillGroup) -> Void
    let onRemoveFromGroup: (() -> Void)?

    @State private var pressed = false

    var body: some View {
        Button(action: { if !isLocked { onTap() } }) {
            VStack(spacing: SDTSpacing.md) {
                // Ring + icon
                ZStack {
                    SDTHealthRing(score: skill.healthScore, lineWidth: 4)
                        .frame(width: 64, height: 64)

                    Image(systemName: skill.category.systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(skill.category.color)
                }

                // Name + status
                VStack(spacing: SDTSpacing.xxs) {
                    Text(skill.name)
                        .sdtFont(.captionSemibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(Color.sdtHealthLabel(for: skill.healthScore))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.sdtHealth(for: skill.healthScore))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.lg)
            .padding(.horizontal, SDTSpacing.sm)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .shadow(color: .black.opacity(isLocked ? 0 : 0.06), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                    .strokeBorder(skill.category.color.opacity(isLocked ? 0.1 : 0.25), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if !isLocked && skill.streakDays > 0 {
                    SDTStreakBadge(days: skill.streakDays)
                        .padding(.horizontal, SDTSpacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.sdtSurface)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
                        )
                        .offset(x: 6, y: -8)
                }
            }
            // Lock overlay
            .overlay {
                if isLocked {
                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                        .fill(Color.sdtBackground.opacity(0.55))
                        .overlay {
                            VStack(spacing: SDTSpacing.xs) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.sdtSecondary)
                                Text("Pro")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.sdtSecondary)
                            }
                        }
                }
            }
            .grayscale(isLocked ? 0.8 : 0)
            .opacity(isLocked ? 0.6 : 1)
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isLocked {
                        withAnimation(.easeInOut(duration: 0.1)) { pressed = true }
                    }
                }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.15)) { pressed = false } }
        )
        .sensoryFeedback(.impact(flexibility: .soft), trigger: pressed)
        .contextMenu { if !isLocked { contextMenuItems } }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        // Move to group submenu
        if !allGroups.isEmpty {
            Menu {
                ForEach(allGroups) { group in
                    let alreadyIn = skill.group?.id == group.id
                    Button {
                        if !alreadyIn { onMove(group) }
                    } label: {
                        Label(
                            "\(group.emoji) \(group.name)",
                            systemImage: alreadyIn ? "checkmark" : "folder"
                        )
                    }
                    .disabled(alreadyIn)
                }
            } label: {
                Label("Move to Group", systemImage: "folder.badge.plus")
            }
        }

        // Remove from current group
        if let removeAction = onRemoveFromGroup {
            Button(role: .destructive, action: removeAction) {
                Label("Remove from Group", systemImage: "folder.badge.minus")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = SkillMapViewModel()
    let skills = [
        Skill(name: "SwiftUI", category: .programming),
        Skill(name: "Combine", category: .programming),
        Skill(name: "Spanish", category: .language),
    ]
    ScrollView {
        SkillGridView(skills: skills, viewModel: vm)
            .padding(SDTSpacing.xl)
    }
    .background(Color.sdtBackground)
}
