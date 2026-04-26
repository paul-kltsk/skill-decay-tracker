import SwiftUI
import SwiftData
import Charts

/// Full-screen Time Intelligence view.
///
/// Sections:
/// 1. Full 12-week activity heatmap with legend
/// 2. Best practice hour distribution (bar chart)
/// 3. Response time overview (average per skill)
struct TimeIntelligenceView: View {

    @Query(sort: \Skill.healthScore) private var skills: [Skill]
    @State private var viewModel = AnalyticsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: SDTSpacing.xxl) {
                heatmapSection
                hourDistributionSection
                responseTimeSection
            }
            .padding(.horizontal, SDTSpacing.xl)
            .padding(.vertical, SDTSpacing.lg)
        }
        .background(Color.sdtBackground)
        .navigationTitle("Time Intelligence")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        let heatmap    = viewModel.activityHeatmap(for: skills)
        let activeDays = heatmap.filter { $0.count > 0 }.count
        let maxCount   = heatmap.map(\.count).max() ?? 0

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity Heatmap")
                    .sdtFont(.bodySemibold)
                Text("\(activeDays) active days in the last 12 weeks")
                    .sdtFont(.caption, color: .sdtSecondary)
            }

            // Day-of-week labels
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.sdtSecondary)
                        .frame(width: 14, height: 14)
                }
                Spacer()
            }

            // Grid (7 rows = days of week, 12 cols = weeks)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: Array(repeating: GridItem(.fixed(13), spacing: 3), count: 7),
                    spacing: 3
                ) {
                    ForEach(heatmap) { day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatmapColor(count: day.count, max: maxCount))
                            .frame(width: 13, height: 13)
                            .help("\(day.count) sessions")
                    }
                }
                .frame(height: 7 * 13 + 6 * 3)
            }

            // Legend
            HStack(spacing: SDTSpacing.sm) {
                Text("Less")
                    .sdtFont(.codeSmall, color: .sdtSecondary)
                ForEach([0, 1, 2, 4], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatmapColor(count: level, max: 4))
                        .frame(width: 13, height: 13)
                }
                Text("More")
                    .sdtFont(.codeSmall, color: .sdtSecondary)
                Spacer()
            }
        }
        .sdtCard()
    }

    private func heatmapColor(count: Int, max: Int) -> Color {
        guard count > 0 else { return Color.sdtSecondary.opacity(0.10) }
        let fraction = max > 0 ? Double(count) / Double(max) : 1.0
        return switch fraction {
        case 0.75...: Color.sdtHealthThriving
        case 0.40...: Color.sdtHealthHealthy
        default:      Color.sdtHealthFading.opacity(0.65)
        }
    }

    // MARK: - Hour Distribution Section

    private var hourDistributionSection: some View {
        let hourData = viewModel.hourDistribution(for: skills)
        let totalSessions = hourData.reduce(0) { $0 + $1.count }
        let peakHour = hourData.max(by: { $0.count < $1.count })

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Best Practice Time")
                    .sdtFont(.bodySemibold)
                if let peak = peakHour, peak.count > 0 {
                    Text("You practice most at \(peak.label)")
                        .sdtFont(.caption, color: .sdtSecondary)
                } else {
                    Text("Complete challenges to see patterns")
                        .sdtFont(.caption, color: .sdtSecondary)
                }
            }

            if totalSessions == 0 {
                emptyPlaceholder(height: 120, message: "No practice data yet")
            } else {
                Chart(hourData) { bucket in
                    BarMark(
                        x: .value("Hour", bucket.hour),
                        y: .value("Count", bucket.count)
                    )
                    .foregroundStyle(
                        bucket.count == (peakHour?.count ?? 0) && bucket.count > 0
                            ? Color.sdtCategoryProgramming
                            : Color.sdtCategoryProgramming.opacity(0.4)
                    )
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { v in
                        AxisGridLine().foregroundStyle(Color.sdtSecondary.opacity(0.1))
                        AxisValueLabel {
                            if let h = v.as(Int.self) {
                                let label = h == 0 ? String(localized: "12am") : h == 12 ? String(localized: "12pm") : h < 12 ? String(localized: "\(h)am") : String(localized: "\(h-12)pm")
                                Text(label)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color.sdtSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine().foregroundStyle(Color.sdtSecondary.opacity(0.08))
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
                .frame(height: 130)
            }
        }
        .sdtCard()
    }

    // MARK: - Response Time Section

    private var responseTimeSection: some View {
        // Average response time per skill (in seconds)
        let responseData: [(name: String, avgTime: Double)] = skills.compactMap { skill in
            let allTimes = (skill.challenges ?? []).flatMap { ($0.results ?? []).map(\.responseTime) }
            guard !allTimes.isEmpty else { return nil }
            let avg = allTimes.reduce(0, +) / Double(allTimes.count)
            return (name: skill.name, avgTime: avg)
        }
        .sorted { $0.avgTime < $1.avgTime }

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Response Times")
                    .sdtFont(.bodySemibold)
                Text("Average seconds per challenge, by skill")
                    .sdtFont(.caption, color: .sdtSecondary)
            }

            if responseData.isEmpty {
                emptyPlaceholder(height: 80, message: "No response data yet")
            } else {
                VStack(spacing: SDTSpacing.sm) {
                    ForEach(responseData, id: \.name) { item in
                        HStack(spacing: SDTSpacing.md) {
                            Text(item.name)
                                .sdtFont(.bodyMedium)
                                .frame(width: 110, alignment: .leading)
                                .lineLimit(1)

                            GeometryReader { geo in
                                let maxTime = responseData.map(\.avgTime).max() ?? 1
                                let fraction = min(1, item.avgTime / maxTime)
                                let color = item.avgTime < 30
                                    ? Color.sdtHealthThriving
                                    : item.avgTime < 60
                                        ? Color.sdtHealthFading
                                        : Color.sdtHealthCritical

                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.sdtSecondary.opacity(0.10))
                                    Capsule()
                                        .fill(color.opacity(0.8))
                                        .frame(width: geo.size.width * fraction)
                                }
                            }
                            .frame(height: 8)

                            Text(String(format: "%.0fs", item.avgTime))
                                .sdtFont(.codeSmall, color: .sdtSecondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .sdtCard()
    }

    // MARK: - Helpers

    private func emptyPlaceholder(height: CGFloat, message: LocalizedStringKey) -> some View {
        Text(message)
            .sdtFont(.bodyMedium, color: .sdtSecondary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.sdtBackground)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { TimeIntelligenceView() }
}
