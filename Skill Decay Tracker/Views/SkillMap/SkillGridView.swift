import SwiftUI

/// 2-column grid view of all skills, used as the alternate layout in ``SkillMapView``.
///
/// Each card shows the health ring, category icon, skill name, health label,
/// and streak badge. Tapping a card opens ``SkillDetailView`` via the shared
/// ``SkillMapViewModel``.
struct SkillGridView: View {

    let skills: [Skill]
    let viewModel: SkillMapViewModel

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
            LazyVGrid(columns: columns, spacing: SDTSpacing.md) {
                ForEach(skills) { skill in
                    GridCard(skill: skill, onTap: { viewModel.select(skill) })
                }
            }
        }
    }
}

// MARK: - GridCard

private struct GridCard: View {

    let skill: Skill
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
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

                // Streak (optional)
                if skill.streakDays > 0 {
                    SDTStreakBadge(days: skill.streakDays)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.lg)
            .padding(.horizontal, SDTSpacing.sm)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                    .strokeBorder(skill.category.color.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) { pressed = false }
                }
        )
        .sensoryFeedback(.impact(flexibility: .soft), trigger: pressed)
    }
}

// MARK: - Preview

#Preview {
    let vm = SkillMapViewModel()
    let skills = [
        Skill(name: "SwiftUI", category: .programming, decayRate: 0.05),
        Skill(name: "Spanish", category: .language, decayRate: 0.12),
        Skill(name: "Git", category: .tool, decayRate: 0.08),
        Skill(name: "SOLID Principles", category: .concept, decayRate: 0.07),
    ]
    ScrollView {
        SkillGridView(skills: skills, viewModel: vm)
            .padding(SDTSpacing.xl)
    }
    .background(Color.sdtBackground)
}
