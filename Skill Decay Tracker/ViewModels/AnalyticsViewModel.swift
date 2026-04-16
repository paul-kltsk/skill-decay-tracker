import SwiftUI
import SwiftData

// MARK: - Time Range

enum AnalyticsTimeRange: String, CaseIterable {
    case week    = "7d"
    case month   = "30d"
    case quarter = "90d"

    var days: Int {
        switch self {
        case .week:    7
        case .month:   30
        case .quarter: 90
        }
    }
}

// MARK: - Data Models

struct TrendPoint: Identifiable {
    let id: Int
    let date: Date
    let health: Double
}

struct SkillHealthDatum: Identifiable {
    let id: UUID
    let name: String
    let health: Double
    let category: SkillCategory
}

struct TypeAccuracyDatum: Identifiable {
    let id: String
    let typeName: String
    let typeIcon: String
    let accuracy: Double
    let count: Int
}

struct ActivityDay: Identifiable {
    let id: Date
    let date: Date
    let count: Int
}

struct HourBucket: Identifiable {
    let id: Int
    let hour: Int
    let count: Int

    var label: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return hour < 12 ? "\(h)am" : "\(h)pm"
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    let progress: Double  // 0…1
}

// MARK: - AnalyticsViewModel

/// ViewModel for ``AnalyticsView``.
///
/// All computed metrics accept the `[Skill]` array from the view's `@Query`
/// so SwiftData changes propagate automatically.
///
/// No SwiftData mutations happen here — this is a pure read/compute layer.
@Observable
@MainActor
final class AnalyticsViewModel {

    // MARK: - UI State

    var timeRange: AnalyticsTimeRange = .month

    // MARK: - Portfolio Metrics

    func portfolioHealth(for skills: [Skill]) -> Double {
        guard !skills.isEmpty else { return 0 }
        return skills.reduce(0) { $0 + $1.healthScore } / Double(skills.count)
    }

    func totalChallenges(for skills: [Skill]) -> Int {
        skills.reduce(0) { $0 + $1.totalPracticeCount }
    }

    func totalCorrect(for skills: [Skill]) -> Int {
        skills.reduce(0) { $0 + $1.correctCount }
    }

    func overallAccuracy(for skills: [Skill]) -> Double? {
        let total = totalChallenges(for: skills)
        guard total > 0 else { return nil }
        return Double(totalCorrect(for: skills)) / Double(total)
    }

    func bestStreak(for skills: [Skill]) -> Int {
        skills.max(by: { $0.streakDays < $1.streakDays })?.streakDays ?? 0
    }

    // MARK: - XP & Level

    func totalXP(for skills: [Skill]) -> Int {
        skills.flatMap { skill in
            (skill.challenges ?? []).flatMap { challenge in
                (challenge.results ?? []).map { result in
                    DecayEngine.xpReward(
                        isCorrect: result.isCorrect,
                        difficulty: challenge.difficulty,
                        confidence: result.confidenceRating
                    )
                }
            }
        }.reduce(0, +)
    }

    func level(xp: Int) -> Int      { 1 + xp / 500 }
    func levelProgress(xp: Int) -> Double { Double(xp % 500) / 500.0 }
    func xpToNext(xp: Int) -> Int   { 500 - (xp % 500) }

    // MARK: - Health Trend

    /// Reconstructs a portfolio health timeline using the decay formula.
    ///
    /// For each past day, estimates what the average health would have been
    /// by "rewinding" each skill's decay clock.
    func healthTrend(for skills: [Skill], range: AnalyticsTimeRange) -> [TrendPoint] {
        guard !skills.isEmpty else { return [] }
        let calendar = Calendar.current
        let now = Date.now

        return (0...range.days).reversed().enumerated().map { idx, daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let avgHealth: Double = skills.reduce(0) { sum, skill in
                let daysSinceAtPoint = skill.daysSinceLastPractice - Double(daysAgo)
                let h = daysSinceAtPoint > 0
                    ? DecayEngine.healthScore(
                        peakScore: skill.peakScore,
                        decayRate: skill.decayRate,
                        daysSinceLastPractice: daysSinceAtPoint
                      )
                    : skill.peakScore
                return sum + min(1, max(0, h))
            } / Double(skills.count)

            return TrendPoint(id: idx, date: date, health: avgHealth)
        }
    }

    // MARK: - Skill Health Comparison

    func skillHealthData(for skills: [Skill]) -> [SkillHealthDatum] {
        skills
            .sorted { $0.healthScore < $1.healthScore }
            .map { SkillHealthDatum(id: $0.id, name: $0.name, health: $0.healthScore, category: $0.category) }
    }

    // MARK: - Challenge Type Accuracy

    func typeAccuracy(for skills: [Skill]) -> [TypeAccuracyDatum] {
        var correct: [ChallengeType: Int] = [:]
        var total: [ChallengeType: Int]   = [:]

        for skill in skills {
            for challenge in skill.challenges ?? [] {
                for result in challenge.results ?? [] {
                    let t = challenge.type
                    total[t, default: 0]   += 1
                    if result.isCorrect { correct[t, default: 0] += 1 }
                }
            }
        }

        return ChallengeType.allCases.compactMap { type in
            guard let n = total[type], n > 0 else { return nil }
            let acc = Double(correct[type, default: 0]) / Double(n)
            return TypeAccuracyDatum(
                id: type.rawValue,
                typeName: type.displayName,
                typeIcon: type.systemImage,
                accuracy: acc,
                count: n
            )
        }
        .sorted { $0.count > $1.count }
    }

    // MARK: - Activity Heatmap (last 12 weeks = 84 days)

    func activityHeatmap(for skills: [Skill]) -> [ActivityDay] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date.now)

        // Collect all practice dates
        var dayCounts: [Date: Int] = [:]
        for skill in skills {
            for challenge in skill.challenges ?? [] {
                for result in challenge.results ?? [] {
                    let day = calendar.startOfDay(for: result.practiceDate)
                    dayCounts[day, default: 0] += 1
                }
            }
        }

        // Build 84-day array (oldest → newest)
        return (0..<84).map { i in
            let daysAgo = 83 - i
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return ActivityDay(id: date, date: date, count: dayCounts[date, default: 0])
        }
    }

    // MARK: - Hourly Distribution

    func hourDistribution(for skills: [Skill]) -> [HourBucket] {
        var counts = [Int: Int]()
        for skill in skills {
            for challenge in skill.challenges ?? [] {
                for result in challenge.results ?? [] {
                    let hour = Calendar.current.component(.hour, from: result.practiceDate)
                    counts[hour, default: 0] += 1
                }
            }
        }
        return (0..<24).map { h in
            HourBucket(id: h, hour: h, count: counts[h, default: 0])
        }
    }

    // MARK: - Achievements

    func achievements(for skills: [Skill]) -> [Achievement] {
        let totalC   = totalChallenges(for: skills)
        let accuracy = overallAccuracy(for: skills) ?? 0
        let streak   = bestStreak(for: skills)
        let xp       = totalXP(for: skills)
        let allDays  = activityHeatmap(for: skills).filter { $0.count > 0 }.count

        return [
            Achievement(
                id: "first_step",
                title: String(localized: "First Step"),
                description: String(localized: "Complete your first challenge"),
                icon: "sparkle",
                isUnlocked: totalC >= 1,
                progress: min(1, Double(totalC))
            ),
            Achievement(
                id: "week_warrior",
                title: String(localized: "Week Warrior"),
                description: String(localized: "Maintain a 7-day streak"),
                icon: "flame.fill",
                isUnlocked: streak >= 7,
                progress: min(1, Double(streak) / 7.0)
            ),
            Achievement(
                id: "collector",
                title: String(localized: "Collector"),
                description: String(localized: "Track 5 or more skills"),
                icon: "books.vertical.fill",
                isUnlocked: skills.count >= 5,
                progress: min(1, Double(skills.count) / 5.0)
            ),
            Achievement(
                id: "sharp_mind",
                title: String(localized: "Sharp Mind"),
                description: String(localized: "Reach 90%+ accuracy over 20 challenges"),
                icon: "target",
                isUnlocked: totalC >= 20 && accuracy >= 0.9,
                progress: totalC < 20
                    ? min(1, Double(totalC) / 20.0)
                    : min(1, accuracy / 0.9)
            ),
            Achievement(
                id: "centurion",
                title: String(localized: "Centurion"),
                description: String(localized: "Complete 100 challenges"),
                icon: "100.circle.fill",
                isUnlocked: totalC >= 100,
                progress: min(1, Double(totalC) / 100.0)
            ),
            Achievement(
                id: "persistent",
                title: String(localized: "Persistent"),
                description: String(localized: "Practice on 30 different days"),
                icon: "calendar.badge.checkmark",
                isUnlocked: allDays >= 30,
                progress: min(1, Double(allDays) / 30.0)
            ),
            Achievement(
                id: "month_warrior",
                title: String(localized: "Month Warrior"),
                description: String(localized: "Maintain a 30-day streak"),
                icon: "crown.fill",
                isUnlocked: streak >= 30,
                progress: min(1, Double(streak) / 30.0)
            ),
            Achievement(
                id: "legend",
                title: String(localized: "Legend"),
                description: String(localized: "Earn 5,000 XP"),
                icon: "trophy.fill",
                isUnlocked: xp >= 5_000,
                progress: min(1, Double(xp) / 5_000.0)
            ),
        ]
    }
}
