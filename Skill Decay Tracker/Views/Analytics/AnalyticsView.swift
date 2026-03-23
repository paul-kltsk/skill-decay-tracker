import SwiftUI
import SwiftData
import Charts

/// Tab 4 — Analytics.
///
/// Sections (all scrollable):
/// 1. Portfolio summary — health ring + 4 key stats
/// 2. Health trend — line chart over selected period
/// 3. Skill health comparison — horizontal bar chart
/// 4. Challenge type accuracy — bar chart
/// 5. Activity preview — mini heatmap → TimeIntelligenceView
/// 6. Achievements preview — XP level card + badge row → AchievementsView
struct AnalyticsView: View {

    @Query(sort: \Skill.healthScore) private var skills: [Skill]
    @State private var viewModel = AnalyticsViewModel()

    var body: some View {
        Group {
            if skills.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: SDTSpacing.xxl) {
                        portfolioSummary
                        healthTrendSection
                        skillComparisonSection
                        typeAccuracySection
                        activitySection
                        achievementsSection
                    }
                    .padding(.horizontal, SDTSpacing.xl)
                    .padding(.vertical, SDTSpacing.lg)
                }
            }
        }
        .background(Color.sdtBackground)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        SDTEmptyState(
            icon: "chart.bar.fill",
            title: "No Data Yet",
            message: "Head to the Skills tab to add your first skill, then complete a practice session to see your analytics here."
        )
        .padding(.horizontal, SDTSpacing.xl)
    }

    // MARK: - Portfolio Summary

    private var portfolioSummary: some View {
        let health    = viewModel.portfolioHealth(for: skills)
        let total     = viewModel.totalChallenges(for: skills)
        let accuracy  = viewModel.overallAccuracy(for: skills)
        let streak    = viewModel.bestStreak(for: skills)
        let xp        = viewModel.totalXP(for: skills)
        let lvl       = viewModel.level(xp: xp)

        return VStack(spacing: SDTSpacing.lg) {
            // Health ring + label
            HStack(spacing: SDTSpacing.xl) {
                ZStack {
                    SDTHealthRing(score: health, lineWidth: 10)
                        .frame(width: 96, height: 96)
                    VStack(spacing: 1) {
                        Text("\(Int(health * 100))")
                            .sdtFont(.numericMedium, color: Color.sdtHealth(for: health))
                        Text("%")
                            .sdtFont(.caption, color: Color.sdtHealth(for: health))
                    }
                }

                VStack(alignment: .leading, spacing: SDTSpacing.xs) {
                    Text("Portfolio Health")
                        .sdtFont(.titleSmall)
                    Text(Color.sdtHealthLabel(for: health))
                        .sdtFont(.bodyMedium, color: Color.sdtHealth(for: health))
                    Text("\(skills.count) skill\(skills.count == 1 ? "" : "s") tracked")
                        .sdtFont(.caption, color: .sdtSecondary)
                }

                Spacer()
            }

            // 4 key stats
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()),
                          GridItem(.flexible()), GridItem(.flexible())],
                spacing: SDTSpacing.sm
            ) {
                miniStat(value: "\(total)", label: "Challenges", icon: "checkmark.circle")
                miniStat(
                    value: accuracy.map { "\(Int($0 * 100))%" } ?? "—",
                    label: "Accuracy",
                    icon: "target"
                )
                miniStat(value: "\(streak)d", label: "Best Streak", icon: "flame")
                miniStat(value: "Lv \(lvl)", label: "Level", icon: "star")
            }
        }
        .sdtCard()
    }

    private func miniStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: SDTSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.sdtSecondary)
            Text(value)
                .sdtFont(.captionSemibold)
            Text(label)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Color.sdtSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SDTSpacing.sm)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip))
    }

    // MARK: - Health Trend

    private var healthTrendSection: some View {
        let trendData = viewModel.healthTrend(for: skills, range: viewModel.timeRange)
        let health    = viewModel.portfolioHealth(for: skills)

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            HStack {
                Text("Health Trend")
                    .sdtFont(.bodySemibold)
                Spacer()
                Picker("Range", selection: $viewModel.timeRange) {
                    ForEach(AnalyticsTimeRange.allCases, id: \.rawValue) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if trendData.isEmpty {
                emptyChartPlaceholder(height: 150, message: "No data yet")
            } else {
                Chart {
                    ForEach(trendData) { pt in
                        AreaMark(
                            x: .value("Date", pt.date),
                            y: .value("Health", pt.health)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.sdtHealth(for: health).opacity(0.22),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Health", pt.health)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.sdtHealth(for: health))
                    }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0.0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Color.sdtSecondary.opacity(0.12))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d * 100))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.sdtSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: trendAxisStride)) { _ in
                        AxisGridLine().foregroundStyle(Color.sdtSecondary.opacity(0.08))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
                .frame(height: 150)
            }
        }
        .sdtCard()
    }

    private var trendAxisStride: Int {
        switch viewModel.timeRange {
        case .week:    2
        case .month:   7
        case .quarter: 30
        }
    }

    // MARK: - Skill Health Comparison

    private var skillComparisonSection: some View {
        let data = viewModel.skillHealthData(for: skills)

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            Text("Skill Health")
                .sdtFont(.bodySemibold)

            if data.isEmpty {
                emptyChartPlaceholder(height: 120, message: "No skills yet")
            } else {
                Chart(data) { datum in
                    BarMark(
                        x: .value("Health", datum.health),
                        y: .value("Skill", datum.name)
                    )
                    .foregroundStyle(Color.sdtHealth(for: datum.health))
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text("\(Int(datum.health * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.sdtHealth(for: datum.health))
                    }
                }
                .chartXScale(domain: 0...1)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { v in
                        AxisValueLabel()
                            .font(.system(size: 12))
                            .foregroundStyle(Color.sdtPrimary)
                    }
                }
                .frame(height: max(80, CGFloat(data.count) * 36))
            }
        }
        .sdtCard()
    }

    // MARK: - Challenge Type Accuracy

    private var typeAccuracySection: some View {
        let data = viewModel.typeAccuracy(for: skills)

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            Text("Accuracy by Challenge Type")
                .sdtFont(.bodySemibold)

            if data.isEmpty {
                emptyChartPlaceholder(height: 100, message: "Complete challenges to see breakdown")
            } else {
                Chart(data) { datum in
                    BarMark(
                        x: .value("Type", datum.typeName),
                        y: .value("Accuracy", datum.accuracy)
                    )
                    .foregroundStyle(
                        datum.accuracy >= 0.7 ? Color.sdtHealthHealthy : Color.sdtHealthFading
                    )
                    .cornerRadius(4)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(Int(datum.accuracy * 100))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0.0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Color.sdtSecondary.opacity(0.12))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d * 100))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.sdtSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { v in
                        AxisValueLabel()
                            .font(.system(size: 11))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
                .frame(height: 160)
            }
        }
        .sdtCard()
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        let heatmap = viewModel.activityHeatmap(for: skills)
        let activeDays = heatmap.filter { $0.count > 0 }.count

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .sdtFont(.bodySemibold)
                    Text("\(activeDays) days active in 12 weeks")
                        .sdtFont(.caption, color: .sdtSecondary)
                }
                Spacer()
                NavigationLink {
                    TimeIntelligenceView()
                } label: {
                    Text("Details")
                        .sdtFont(.captionSemibold, color: .sdtCategoryTool)
                }
            }

            MiniHeatmap(days: heatmap)
        }
        .sdtCard()
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        let xp           = viewModel.totalXP(for: skills)
        let lvl          = viewModel.level(xp: xp)
        let progress     = viewModel.levelProgress(xp: xp)
        let toNext       = viewModel.xpToNext(xp: xp)
        let achievements = viewModel.achievements(for: skills)
        let unlocked     = achievements.filter { $0.isUnlocked }.count

        return VStack(alignment: .leading, spacing: SDTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .sdtFont(.bodySemibold)
                    Text("\(unlocked)/\(achievements.count) unlocked")
                        .sdtFont(.caption, color: .sdtSecondary)
                }
                Spacer()
                NavigationLink {
                    AchievementsView()
                } label: {
                    Text("See All")
                        .sdtFont(.captionSemibold, color: .sdtCategoryTool)
                }
            }

            // XP + Level card
            HStack(spacing: SDTSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(Color.sdtSecondary.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.sdtCategoryProgramming,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(lvl)")
                        .sdtFont(.numericMedium, color: .sdtCategoryProgramming)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: SDTSpacing.xxs) {
                    Text("Level \(lvl)")
                        .sdtFont(.bodySemibold)
                    Text("\(xp) XP · \(toNext) to next level")
                        .sdtFont(.caption, color: .sdtSecondary)
                    SDTProgressBar(value: progress)
                        .frame(height: 4)
                }
            }
            .sdtCard(padding: SDTSpacing.md)

            // Badge preview (first 4)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 4),
                spacing: SDTSpacing.sm
            ) {
                ForEach(achievements.prefix(4)) { a in
                    BadgeCell(achievement: a)
                }
            }
        }
        .sdtCard()
    }

    // MARK: - Helpers

    private func emptyChartPlaceholder(height: CGFloat, message: String) -> some View {
        Text(message)
            .sdtFont(.bodyMedium, color: .sdtSecondary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.sdtBackground)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip))
    }
}

// MARK: - MiniHeatmap

/// Compact 12-week activity heatmap for the Analytics overview section.
private struct MiniHeatmap: View {

    let days: [ActivityDay]

    private let cellSize: CGFloat = 10
    private let gap: CGFloat = 3

    var body: some View {
        LazyHGrid(
            rows: Array(repeating: GridItem(.fixed(cellSize), spacing: gap), count: 7),
            spacing: gap
        ) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: day.count))
                    .frame(width: cellSize, height: cellSize)
            }
        }
        .frame(height: 7 * cellSize + 6 * gap)
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0:      Color.sdtSecondary.opacity(0.12)
        case 1:      Color.sdtHealthFading.opacity(0.55)
        case 2:      Color.sdtHealthHealthy.opacity(0.70)
        default:     Color.sdtHealthThriving
        }
    }
}

// MARK: - BadgeCell

private struct BadgeCell: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: SDTSpacing.xxs) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked
                          ? Color.sdtCategoryProgramming.opacity(0.15)
                          : Color.sdtSecondary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        achievement.isUnlocked
                            ? Color.sdtCategoryProgramming
                            : Color.sdtSecondary.opacity(0.4)
                    )
            }
            Text(achievement.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.sdtSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { AnalyticsView() }
}
