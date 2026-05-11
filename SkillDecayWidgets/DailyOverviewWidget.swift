import WidgetKit
import SwiftUI

// MARK: - Daily Overview Widget (Medium)
//
// Shows top 3 most urgent skills with health bars + current max streak.

struct DailyOverviewWidget: Widget {
    let kind = "sdt.widget.daily"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SDTProvider()) { entry in
            DailyOverviewView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Overview")
        .description("Your top 3 skills to review today.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

private struct DailyOverviewView: View {
    let entry: SDTEntry

    private var topSkills: [WidgetSkillData] {
        Array(entry.snapshot.skills.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Today's Focus")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                if entry.snapshot.maxStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("\(entry.snapshot.maxStreak)d")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 10)

            if topSkills.isEmpty {
                Spacer()
                Text("Add skills in the app to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                VStack(spacing: 8) {
                    ForEach(topSkills) { skill in
                        SkillRow(skill: skill)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SkillRow: View {
    let skill: WidgetSkillData

    private var healthColor: Color { .sdtHealth(skill.healthScore) }
    private var categoryColor: Color { .sdtCategory(skill.category) }
    private var pct: Int { Int(skill.healthScore * 100) }

    var body: some View {
        HStack(spacing: 10) {
            // Category dot
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)

            // Skill name
            Text(skill.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Health bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(healthColor.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(healthColor)
                        .frame(width: geo.size.width * skill.healthScore, height: 5)
                }
            }
            .frame(width: 60, height: 5)

            // Percentage
            Text("\(pct)%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(healthColor)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    DailyOverviewWidget()
} timeline: {
    SDTEntry(date: .now, snapshot: .placeholder)
}
