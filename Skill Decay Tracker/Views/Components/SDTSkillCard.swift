import SwiftUI

/// A card that summarises a skill's health, name, category, and streak.
///
/// Used in `HomeView` (list) and `SkillMapView` (grid).
///
/// ```swift
/// SDTSkillCard(skill: skill)
/// ```
struct SDTSkillCard: View {

    let skill: Skill

    // MARK: Body

    var body: some View {
        HStack(spacing: SDTSpacing.md) {
            ringWithIcon

            info

            Spacer(minLength: 0)

            scoreColumn
        }
        .padding(SDTSpacing.md)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    private var ringWithIcon: some View {
        SDTHealthRing(score: skill.healthScore, lineWidth: 5)
            .frame(width: 52, height: 52)
            .overlay {
                Image(systemName: skill.category.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(skill.category.color)
            }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.xs) {
            Text(skill.name)
                .sdtFont(.bodySemibold)
                .lineLimit(1)

            HStack(spacing: SDTSpacing.xs) {
                Text(Color.sdtHealthLabel(for: skill.healthScore))
                    .sdtFont(.captionSemibold,
                             color: Color.sdtHealth(for: skill.healthScore))

                Text("·")
                    .sdtFont(.caption, color: .sdtSecondary)

                Text(skill.lastPracticed.relativeString)
                    .sdtFont(.caption, color: .sdtSecondary)
            }
        }
    }

    private var scoreColumn: some View {
        VStack(alignment: .trailing, spacing: SDTSpacing.xxs) {
            Text("\(Int((skill.healthScore * 100).rounded()))%")
                .sdtFont(.numericMedium, color: Color.sdtHealth(for: skill.healthScore))

            if skill.streakDays > 0 {
                SDTStreakBadge(days: skill.streakDays)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let health = Color.sdtHealthLabel(for: skill.healthScore)
        let pct    = Int((skill.healthScore * 100).rounded())
        var desc   = "\(skill.name), \(health), \(pct)%"
        if skill.streakDays > 0 { desc += ", \(skill.streakDays) day streak" }
        return desc
    }
}

// MARK: - Preview

#Preview {
    let skill = Skill(name: "Swift", category: .programming)
    return SDTSkillCard(skill: skill)
        .padding()
}
