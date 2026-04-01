import WidgetKit
import SwiftUI

// MARK: - Skill Map Mini Widget (Large)
//
// Displays all skills as a dot grid — category color, opacity = health score.
// Gives a "constellation" overview of the entire knowledge portfolio.

struct SkillMapMiniWidget: Widget {
    let kind = "sdt.widget.map"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SDTProvider()) { entry in
            SkillMapMiniView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Skill Map")
        .description("Your full knowledge portfolio at a glance.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - View

private struct SkillMapMiniView: View {
    let entry: SDTEntry

    private var skills: [WidgetSkillData] { entry.snapshot.skills }
    private var avgHealth: Int {
        guard !skills.isEmpty else { return 0 }
        return Int(skills.map(\.healthScore).reduce(0, +) / Double(skills.count) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill Map")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("\(skills.count) skill\(skills.count == 1 ? "" : "s")  •  avg \(avgHealth)%")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if entry.snapshot.maxStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("\(entry.snapshot.maxStreak)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if skills.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Add skills in the app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                SkillDotGrid(skills: Array(skills.prefix(24)))
                Spacer(minLength: 0)
                HealthLegend()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Dot Grid

private struct SkillDotGrid: View {
    let skills: [WidgetSkillData]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(skills) { skill in
                SkillDot(skill: skill)
            }
        }
    }
}

private struct SkillDot: View {
    let skill: WidgetSkillData

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.sdtCategory(skill.category).opacity(0.15))
            Circle()
                .fill(Color.sdtCategory(skill.category))
                .scaleEffect(0.55 + skill.healthScore * 0.35)
                .opacity(0.5 + skill.healthScore * 0.5)
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - Legend

private struct HealthLegend: View {
    private let items: [(String, Color)] = [
        ("Thriving", .sdtHealth(1.0)),
        ("Healthy",  .sdtHealth(0.8)),
        ("Fading",   .sdtHealth(0.6)),
        ("Critical", .sdtHealth(0.1)),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.0) { label, color in
                HStack(spacing: 3) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    SkillMapMiniWidget()
} timeline: {
    SDTEntry(date: .now, snapshot: .placeholder)
}
