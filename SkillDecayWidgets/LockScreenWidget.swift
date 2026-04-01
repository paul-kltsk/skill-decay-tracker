import WidgetKit
import SwiftUI

// MARK: - Lock Screen Widget
//
// Supports two accessory families:
// • accessoryCircular  — Health ring of the most urgent skill
// • accessoryRectangular — Skill name + health bar + days ago

struct LockScreenWidget: Widget {
    let kind = "sdt.widget.lockscreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SDTProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Skill Status")
        .description("Most urgent skill on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Root View

private struct LockScreenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SDTEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView(skill: entry.snapshot.mostUrgent)
        case .accessoryRectangular:
            RectangularView(skill: entry.snapshot.mostUrgent)
        default:
            EmptyView()
        }
    }
}

// MARK: - Circular

private struct CircularView: View {
    let skill: WidgetSkillData?

    var body: some View {
        if let skill {
            ZStack {
                // Background track
                Circle()
                    .stroke(.secondary.opacity(0.3), lineWidth: 4)
                // Health arc
                Circle()
                    .trim(from: 0, to: skill.healthScore)
                    .stroke(
                        Color.sdtHealth(skill.healthScore),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                // Center text
                Text("\(Int(skill.healthScore * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
        } else {
            Image(systemName: "sparkles")
                .font(.title3)
        }
    }
}

// MARK: - Rectangular

private struct RectangularView: View {
    let skill: WidgetSkillData?

    var body: some View {
        if let skill {
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.secondary.opacity(0.2))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.sdtHealth(skill.healthScore))
                            .frame(width: geo.size.width * skill.healthScore, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(Int(skill.healthScore * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.sdtHealth(skill.healthScore))
                    Spacer()
                    Text(sdtDaysAgo(skill.daysSinceLastPractice))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("No skills")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    LockScreenWidget()
} timeline: {
    SDTEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .accessoryRectangular) {
    LockScreenWidget()
} timeline: {
    SDTEntry(date: .now, snapshot: .placeholder)
}
