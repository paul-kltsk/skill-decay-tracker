import SwiftUI
import Charts

/// Mini decay-curve chart showing predicted health over the next `days` days.
///
/// Visualises the Ebbinghaus forgetting curve using ``DecayEngine.healthScore``
/// for each day interval. Annotated with:
/// - A dashed "review threshold" rule at 70 %
/// - A vertical "today" marker at day 0 (last practiced)
///
/// ```swift
/// SDTDecayCurve(skill: skill)
///     .frame(height: 140)
/// ```
struct SDTDecayCurve: View {

    let skill: Skill

    /// How many days of forecast to display.
    var days: Int = 30

    // MARK: - Data

    private struct DataPoint: Identifiable {
        let id: Int
        let day: Int
        let health: Double
    }

    private var dataPoints: [DataPoint] {
        (0...days).map { day in
            DataPoint(
                id: day,
                day: day,
                health: DecayEngine.healthScore(
                    peakScore: skill.peakScore,
                    decayRate: skill.decayRate,
                    daysSinceLastPractice: Double(day)
                )
            )
        }
    }

    /// Day marker for "now" (clamped to the displayed range).
    private var todayDay: Int {
        min(Int(skill.daysSinceLastPractice), days)
    }

    // MARK: - Body

    var body: some View {
        Chart {
            // Area fill under the curve
            ForEach(dataPoints) { pt in
                AreaMark(
                    x: .value("Day", pt.day),
                    y: .value("Health", pt.health)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.sdtHealth(for: skill.healthScore).opacity(0.20),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Decay line
            ForEach(dataPoints) { pt in
                LineMark(
                    x: .value("Day", pt.day),
                    y: .value("Health", pt.health)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.sdtHealth(for: skill.healthScore))
            }

            // Review threshold (70 %)
            RuleMark(y: .value("Review", 0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.sdtSecondary.opacity(0.45))
                .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                    Text("70%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.sdtSecondary)
                }

            // Today marker
            if todayDay > 0 {
                RuleMark(x: .value("Today", todayDay))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.sdtSecondary.opacity(0.4))
            }
        }
        .chartYScale(domain: 0...1)
        .chartXScale(domain: 0...days)
        .chartYAxis {
            AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                AxisGridLine()
                    .foregroundStyle(Color.sdtSecondary.opacity(0.12))
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text("\(Int(d * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 7, 14, 21, 30]) { value in
                AxisGridLine()
                    .foregroundStyle(Color.sdtSecondary.opacity(0.12))
                AxisValueLabel {
                    if let d = value.as(Int.self) {
                        Text("d\(d)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let skill = Skill(name: "SwiftUI", category: .programming, decayRate: 0.08)
    return SDTDecayCurve(skill: skill)
        .frame(height: 150)
        .padding()
}
