import WidgetKit
import SwiftUI

// MARK: - Skill Spotlight Widget (Small)
//
// Shows the single most urgent skill (lowest health score).
// Tapping opens the app to that skill's detail.

struct SkillSpotlightWidget: Widget {
    let kind = "sdt.widget.spotlight"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SDTProvider()) { entry in
            SkillSpotlightView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Skill Spotlight")
        .description("Your most urgent skill at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - View

private struct SkillSpotlightView: View {
    let entry: SDTEntry

    var body: some View {
        if let skill = entry.snapshot.mostUrgent {
            SpotlightContent(skill: skill)
        } else {
            EmptySpotlight()
        }
    }
}

private struct SpotlightContent: View {
    let skill: WidgetSkillData

    private var healthColor: Color { .sdtHealth(skill.healthScore) }
    private var categoryColor: Color { .sdtCategory(skill.category) }
    private var pct: Int { Int(skill.healthScore * 100) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category tag
            HStack(spacing: 4) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 6, height: 6)
                Text(skill.category)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            // Skill name
            Text(skill.name)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            // Health ring + percentage
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(healthColor.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: skill.healthScore)
                        .stroke(healthColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(pct)%")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(healthColor)
                    Text(sdtHealthLabel(skill.healthScore))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 6)

            // Last practice
            Text(sdtDaysAgo(skill.daysSinceLastPractice))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct EmptySpotlight: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No skills yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SkillSpotlightWidget()
} timeline: {
    SDTEntry(date: .now, snapshot: .placeholder)
}
