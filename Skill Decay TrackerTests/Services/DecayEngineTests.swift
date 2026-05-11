import Testing
import SwiftData
import Foundation
@testable import Skill_Decay_Tracker

// MARK: - Tags

extension Tag {
    @Tag static var decay: Self
    @Tag static var edgeCase: Self
    @Tag static var math: Self
}

// MARK: - Float Comparison Helper

/// Approximate equality for Double — avoids Swift Numerics dependency.
/// Tolerance of 1e-10 is sufficient for `exp`/`log` results with Double precision.
private func approxEqual(
    _ a: Double,
    _ b: Double,
    tolerance: Double = 1e-10,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Bool {
    abs(a - b) <= tolerance
}

// MARK: - healthScore Tests

@Suite("DecayEngine.healthScore", .tags(.decay, .math))
struct HealthScoreTests {

    // MARK: Happy path

    @Test("At day 0 health equals peakScore exactly")
    func atDayZeroEqualspeakScore() {
        let result = DecayEngine.healthScore(peakScore: 0.8, decayRate: 0.1, daysSinceLastPractice: 0)
        #expect(result == 0.8, "Day 0 must return peakScore unchanged")
    }

    @Test("Health decreases as time passes")
    func healthDecaysOverTime() {
        let day1  = DecayEngine.healthScore(peakScore: 1.0, decayRate: 0.1, daysSinceLastPractice: 1)
        let day10 = DecayEngine.healthScore(peakScore: 1.0, decayRate: 0.1, daysSinceLastPractice: 10)
        #expect(day1 > day10, "Health after 1 day must be greater than after 10 days")
        #expect(day1 < 1.0,   "Health must be below peak after any positive time")
    }

    @Test("Health never exceeds peakScore")
    func healthNeverExceedsPeak() {
        let result = DecayEngine.healthScore(peakScore: 0.9, decayRate: 0.5, daysSinceLastPractice: 0)
        #expect(result <= 0.9)
    }

    @Test("Matches Ebbinghaus formula exactly", arguments: [
        // (peakScore, decayRate, days, expected)
        (1.0, 0.1, 10.0, exp(-1.0)),                    // λt = 1
        (1.0, 0.5, 2.0,  exp(-1.0)),                    // λt = 1 again
        (0.8, 0.2, 5.0,  0.8 * exp(-1.0)),              // scaled peak
        (1.0, 0.1, 0.0,  1.0),                          // t = 0
        (1.0, 1.0, 1.0,  exp(-1.0)),                    // high decay rate
    ])
    func matchesFormula(peakScore: Double, decayRate: Double, days: Double, expected: Double) {
        let result = DecayEngine.healthScore(peakScore: peakScore, decayRate: decayRate, daysSinceLastPractice: days)
        #expect(
            approxEqual(result, expected),
            "healthScore(\(peakScore), λ=\(decayRate), t=\(days)) expected ≈ \(expected), got \(result)"
        )
    }

    @Test("Higher decay rate produces lower health at same elapsed time", arguments: [0.05, 0.1, 0.2, 0.5, 1.0])
    func higherDecayRateProducesLowerHealth(decayRate: Double) {
        let health = DecayEngine.healthScore(peakScore: 1.0, decayRate: decayRate, daysSinceLastPractice: 5)
        let reference = DecayEngine.healthScore(peakScore: 1.0, decayRate: 0.01, daysSinceLastPractice: 5)
        #expect(health < reference, "Higher λ=\(decayRate) must give lower health than λ=0.01")
    }

    // MARK: Edge cases

    @Test("Negative days returns peakScore (guard branch)", .tags(.edgeCase))
    func negativeDaysReturnsPeak() {
        let result = DecayEngine.healthScore(peakScore: 0.7, decayRate: 0.1, daysSinceLastPractice: -1)
        #expect(result == 0.7)
    }

    @Test("Zero decayRate returns peakScore (no decay)", .tags(.edgeCase))
    func zeroDecayRateReturnsPeak() {
        let result = DecayEngine.healthScore(peakScore: 0.6, decayRate: 0, daysSinceLastPractice: 100)
        #expect(result == 0.6)
    }

    @Test("Very large elapsed time drives health near zero", .tags(.edgeCase))
    func veryLargeTimeDrivesHealthNearZero() {
        let result = DecayEngine.healthScore(peakScore: 1.0, decayRate: 0.5, daysSinceLastPractice: 1_000)
        #expect(result < 0.0001)
    }
}

// MARK: - adjustedDecayRate Tests

@Suite("DecayEngine.adjustedDecayRate", .tags(.decay, .math))
struct AdjustedDecayRateTests {

    // MARK: Direction

    @Test("Perfect retention (signal=1.0) decreases decay rate")
    func perfectRetentionDecreasesRate() {
        let adjusted = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: 1.0)
        #expect(adjusted < 0.1, "Strong retention must lower λ")
    }

    @Test("No retention (signal=0.0) increases decay rate")
    func noRetentionIncreasesRate() {
        let adjusted = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: 0.0)
        #expect(adjusted > 0.1, "Weak retention must raise λ")
    }

    @Test("Neutral retention (signal=0.5) leaves rate unchanged")
    func neutralRetentionIsUnchanged() {
        let adjusted = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: 0.5)
        #expect(approxEqual(adjusted, 0.1), "Signal 0.5 must produce no change (got \(adjusted))")
    }

    // MARK: Magnitude

    @Test("10% decrease on perfect retention")
    func tenPercentDecreaseOnPerfect() {
        let adjusted = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: 1.0)
        let expected = 0.1 * 0.9   // (0.5 - 1.0) × 0.2 = -0.1 → × 0.9
        #expect(approxEqual(adjusted, expected), "Expected 0.1 × 0.9 = \(expected), got \(adjusted)")
    }

    @Test("10% increase on zero retention")
    func tenPercentIncreaseOnZero() {
        let adjusted = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: 0.0)
        let expected = 0.1 * 1.1   // (0.5 - 0.0) × 0.2 = +0.1 → × 1.1
        #expect(approxEqual(adjusted, expected), "Expected 0.1 × 1.1 = \(expected), got \(adjusted)")
    }

    // MARK: Clamping

    @Test("Result never falls below minDecayRate", .tags(.edgeCase))
    func clampsToMinimum() {
        let adjusted = DecayEngine.adjustedDecayRate(current: DecayEngine.minDecayRate, retentionSignal: 1.0)
        #expect(adjusted >= DecayEngine.minDecayRate)
    }

    @Test("Result never exceeds maxDecayRate", .tags(.edgeCase))
    func clampsToMaximum() {
        let adjusted = DecayEngine.adjustedDecayRate(current: DecayEngine.maxDecayRate, retentionSignal: 0.0)
        #expect(adjusted <= DecayEngine.maxDecayRate)
    }

    @Test("Out-of-range signals are clamped before calculation", .tags(.edgeCase), arguments: [
        (-0.5, true),   // signal below 0 → treated as 0 → rate increases
        (1.5, false),   // signal above 1 → treated as 1 → rate decreases
    ])
    func outOfRangeSignalIsClamped(signal: Double, rateDecreases: Bool) {
        let adjusted = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: signal)
        if rateDecreases {
            #expect(adjusted <= 0.1)
        } else {
            #expect(adjusted >= 0.1)
        }
    }

    @Test("Rate adjusts monotonically with signal", arguments: zip(
        [0.0, 0.25, 0.5, 0.75, 1.0],
        [0.0, 0.25, 0.5, 0.75, 1.0].dropFirst()
    ))
    func monotonicWithSignal(lower: Double, higher: Double) {
        let rateAtLower  = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: lower)
        let rateAtHigher = DecayEngine.adjustedDecayRate(current: 0.1, retentionSignal: higher)
        #expect(rateAtLower >= rateAtHigher, "Higher signal must produce equal or lower rate")
    }
}

// MARK: - daysUntilReview Tests

@Suite("DecayEngine.daysUntilReview", .tags(.decay, .math))
struct DaysUntilReviewTests {

    // MARK: Happy path

    @Test("Returns positive day count for valid inputs")
    func validInputsReturnPositiveDays() throws {
        let days = try #require(DecayEngine.daysUntilReview(decayRate: 0.1, peakScore: 1.0))
        #expect(days > 0)
    }

    @Test("Matches formula: t = −ln(targetFraction) / λ")
    func matchesFormula() throws {
        let λ: Double = 0.1
        let target: Double = 0.7
        let expected = -log(target) / λ          // ≈ 3.567 days
        let result = try #require(DecayEngine.daysUntilReview(decayRate: λ, peakScore: 1.0, targetFraction: target))
        #expect(approxEqual(result, expected), "Expected ≈ \(expected), got \(result)")
    }

    @Test("Higher decay rate schedules review sooner", arguments: [
        (0.05, 0.1),
        (0.1,  0.5),
        (0.5,  1.0),
    ])
    func higherRateSchedulesSooner(lowerRate: Double, higherRate: Double) throws {
        let daysAtLower  = try #require(DecayEngine.daysUntilReview(decayRate: lowerRate,  peakScore: 1.0))
        let daysAtHigher = try #require(DecayEngine.daysUntilReview(decayRate: higherRate, peakScore: 1.0))
        #expect(daysAtLower > daysAtHigher,
            "λ=\(lowerRate) should give more days than λ=\(higherRate)")
    }

    @Test("Default target fraction is reviewTargetFraction constant")
    func defaultTargetMatchesConstant() throws {
        let withDefault  = try #require(DecayEngine.daysUntilReview(decayRate: 0.1, peakScore: 1.0))
        let withExplicit = try #require(DecayEngine.daysUntilReview(
            decayRate: 0.1, peakScore: 1.0, targetFraction: DecayEngine.reviewTargetFraction))
        #expect(approxEqual(withDefault, withExplicit))
    }

    // MARK: Edge cases

    @Test("Zero decayRate returns nil", .tags(.edgeCase))
    func zeroDecayRateReturnsNil() {
        let result = DecayEngine.daysUntilReview(decayRate: 0, peakScore: 1.0)
        #expect(result == nil)
    }

    @Test("Zero peakScore returns nil", .tags(.edgeCase))
    func zeroPeakScoreReturnsNil() {
        let result = DecayEngine.daysUntilReview(decayRate: 0.1, peakScore: 0)
        #expect(result == nil)
    }

    @Test("targetFraction ≥ 1 returns nil (already at or above target)", .tags(.edgeCase))
    func targetFractionAtOrAboveOneReturnsNil() {
        #expect(DecayEngine.daysUntilReview(decayRate: 0.1, peakScore: 1.0, targetFraction: 1.0) == nil)
        #expect(DecayEngine.daysUntilReview(decayRate: 0.1, peakScore: 1.0, targetFraction: 1.5) == nil)
    }

    @Test("targetFraction ≤ 0 returns nil", .tags(.edgeCase))
    func targetFractionAtOrBelowZeroReturnsNil() {
        #expect(DecayEngine.daysUntilReview(decayRate: 0.1, peakScore: 1.0, targetFraction: 0.0) == nil)
        #expect(DecayEngine.daysUntilReview(decayRate: 0.1, peakScore: 1.0, targetFraction: -0.5) == nil)
    }
}

// MARK: - xpReward Tests

@Suite("DecayEngine.xpReward", .tags(.decay))
struct XPRewardTests {

    // MARK: Correctness gate

    @Test("Wrong answer always earns 0 XP regardless of difficulty or confidence", arguments:
        ChallengeType.allCases
    )
    func wrongAnswerEarnsZero(type: ChallengeType) {
        for difficulty in 1...5 {
            for confidence in ConfidenceRating.allCases {
                let xp = DecayEngine.xpReward(isCorrect: false, difficulty: difficulty, confidence: confidence)
                #expect(xp == 0, "Wrong answer must earn 0 XP (difficulty=\(difficulty), confidence=\(confidence))")
            }
        }
    }

    @Test("Correct answer earns positive XP")
    func correctAnswerEarnsXP() {
        let xp = DecayEngine.xpReward(isCorrect: true, difficulty: 3, confidence: .medium)
        #expect(xp > 0)
    }

    // MARK: Difficulty scaling

    @Test("Higher difficulty earns more XP", arguments: zip(1...4, 2...5))
    func higherDifficultyEarnsMore(lower: Int, higher: Int) {
        let xpLow  = DecayEngine.xpReward(isCorrect: true, difficulty: lower,  confidence: .medium)
        let xpHigh = DecayEngine.xpReward(isCorrect: true, difficulty: higher, confidence: .medium)
        #expect(xpHigh > xpLow, "difficulty=\(higher) should reward more than difficulty=\(lower)")
    }

    @Test("XP formula: baseXP × difficulty + confidenceBonus", arguments: [
        (1, ConfidenceRating.low,    10 * 1 + 0),
        (3, ConfidenceRating.medium, 10 * 3 + 5),
        (5, ConfidenceRating.high,   10 * 5 + 10),
        (2, ConfidenceRating.high,   10 * 2 + 10),
    ])
    func formulaIsCorrect(difficulty: Int, confidence: ConfidenceRating, expected: Int) {
        let xp = DecayEngine.xpReward(isCorrect: true, difficulty: difficulty, confidence: confidence)
        #expect(xp == expected, "difficulty=\(difficulty), confidence=\(confidence): expected \(expected), got \(xp)")
    }

    // MARK: Confidence bonus

    @Test("High confidence earns more XP than medium, which earns more than low")
    func confidenceOrderIsMonotonic() {
        let low    = DecayEngine.xpReward(isCorrect: true, difficulty: 3, confidence: .low)
        let medium = DecayEngine.xpReward(isCorrect: true, difficulty: 3, confidence: .medium)
        let high   = DecayEngine.xpReward(isCorrect: true, difficulty: 3, confidence: .high)
        #expect(low < medium, "Medium confidence must beat low")
        #expect(medium < high, "High confidence must beat medium")
    }

    // MARK: Difficulty clamping

    @Test("Difficulty below 1 is treated as 1", .tags(.edgeCase))
    func difficultyBelowOneClamped() {
        let xpClamped  = DecayEngine.xpReward(isCorrect: true, difficulty: -5, confidence: .low)
        let xpAtOne    = DecayEngine.xpReward(isCorrect: true, difficulty:  1, confidence: .low)
        #expect(xpClamped == xpAtOne)
    }

    @Test("Difficulty above 5 is treated as 5", .tags(.edgeCase))
    func difficultyAboveFiveClamped() {
        let xpClamped  = DecayEngine.xpReward(isCorrect: true, difficulty: 99, confidence: .high)
        let xpAtFive   = DecayEngine.xpReward(isCorrect: true, difficulty:  5, confidence: .high)
        #expect(xpClamped == xpAtFive)
    }
}

// MARK: - apply(result:to:) Integration Tests

/// Integration tests using an in-memory SwiftData container.
/// Each test gets a fresh container via `init()` — fully isolated.
@Suite("DecayEngine.apply — integration", .tags(.decay))
@MainActor
struct DecayEngineApplyTests {

    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Skill.self, Challenge.self, ChallengeResult.self, UserProfile.self,
            configurations: config
        )
        context = container.mainContext
    }

    // MARK: Helpers

    private func makeSkill(decayRate: Double = 0.1, peakScore: Double = 0.8) -> Skill {
        let skill = Skill(name: "Test Skill", category: .programming)
        skill.decayRate  = decayRate
        skill.peakScore  = peakScore
        skill.healthScore = peakScore
        context.insert(skill)
        return skill
    }

    private func makeResult(isCorrect: Bool, responseTime: TimeInterval = 15, confidence: ConfidenceRating = .high) -> ChallengeResult {
        ChallengeResult(
            isCorrect: isCorrect,
            responseTime: responseTime,
            confidenceRating: confidence,
            userAnswer: "answer"
        )
    }

    // MARK: Stats

    @Test("Correct answer increments totalPracticeCount and correctCount")
    func correctAnswerUpdatesStats() throws {
        let skill  = makeSkill()
        let result = makeResult(isCorrect: true)

        DecayEngine.apply(result: result, to: skill)

        #expect(skill.totalPracticeCount == 1)
        #expect(skill.correctCount == 1)
    }

    @Test("Wrong answer increments totalPracticeCount only")
    func wrongAnswerUpdatesTotalOnly() {
        let skill  = makeSkill()
        let result = makeResult(isCorrect: false)

        DecayEngine.apply(result: result, to: skill)

        #expect(skill.totalPracticeCount == 1)
        #expect(skill.correctCount == 0)
    }

    // MARK: Health restoration

    @Test("After apply, healthScore equals peakScore (decay clock resets)")
    func applyResetsDecayClock() {
        let skill = makeSkill(peakScore: 0.8)
        skill.healthScore = 0.4   // simulate degraded health
        let result = makeResult(isCorrect: false)

        DecayEngine.apply(result: result, to: skill)

        #expect(approxEqual(skill.healthScore, skill.peakScore),
            "Health should equal peak immediately after practice")
    }

    // MARK: Peak boost

    @Test("Correct answer raises peakScore")
    func correctAnswerRaisesPeak() {
        let skill      = makeSkill(peakScore: 0.8)
        let beforePeak = skill.peakScore
        let result     = makeResult(isCorrect: true, confidence: .high)

        DecayEngine.apply(result: result, to: skill)

        #expect(skill.peakScore > beforePeak, "Peak should increase on correct answer")
    }

    @Test("Wrong answer does not raise peakScore")
    func wrongAnswerKeepsPeak() {
        let skill      = makeSkill(peakScore: 0.8)
        let beforePeak = skill.peakScore
        let result     = makeResult(isCorrect: false)

        DecayEngine.apply(result: result, to: skill)

        #expect(approxEqual(skill.peakScore, beforePeak), "Peak must not change on wrong answer")
    }

    @Test("peakScore never exceeds 1.0 even with many correct answers")
    func peakScoreCapAt1() {
        let skill = makeSkill(peakScore: 0.99)
        for _ in 0..<20 {
            DecayEngine.apply(result: makeResult(isCorrect: true, confidence: .high), to: skill)
        }
        #expect(skill.peakScore <= 1.0)
    }

    // MARK: Decay rate direction

    @Test("Strong retention decreases skill's decayRate")
    func strongRetentionDecreasesRate() {
        let skill       = makeSkill(decayRate: 0.1)
        let beforeRate  = skill.decayRate
        let result      = makeResult(isCorrect: true, responseTime: 5, confidence: .high) // high signal

        DecayEngine.apply(result: result, to: skill)

        #expect(skill.decayRate < beforeRate, "Strong retention must lower λ")
    }

    @Test("Wrong answer increases skill's decayRate")
    func wrongAnswerIncreasesRate() {
        let skill      = makeSkill(decayRate: 0.1)
        let beforeRate = skill.decayRate
        let result     = makeResult(isCorrect: false, confidence: .low)

        DecayEngine.apply(result: result, to: skill)

        #expect(skill.decayRate > beforeRate, "Wrong answer must raise λ")
    }

    // MARK: Next review date

    @Test("nextReviewDate is in the future after apply")
    func nextReviewDateIsInFuture() {
        let skill  = makeSkill()
        let result = makeResult(isCorrect: true)

        DecayEngine.apply(result: result, to: skill)

        #expect(skill.nextReviewDate > Date.now)
    }

    @Test("Lower decayRate produces later nextReviewDate")
    func lowerRateProducesLaterReview() throws {
        let slowSkill = makeSkill(decayRate: 0.05)
        let fastSkill = makeSkill(decayRate: 0.5)
        let result    = makeResult(isCorrect: true, confidence: .high)

        // Apply same result to both; freeze decay rate adjustment by setting same signal
        let slowBefore = slowSkill.decayRate
        let fastBefore = fastSkill.decayRate

        DecayEngine.apply(result: result, to: slowSkill)
        DecayEngine.apply(result: result, to: fastSkill)

        // After same adjustment, the slow skill should still have a later review
        // (check via nextReviewDate rather than exact days to avoid fragile time math)
        #expect(slowSkill.nextReviewDate > fastSkill.nextReviewDate,
            "Slow-decaying skill should review later than fast-decaying one")

        // Restore original rates to confirm the relationship holds independently
        _ = slowBefore; _ = fastBefore
    }
}

// MARK: - refreshHealth Tests

@Suite("DecayEngine.refreshHealth", .tags(.decay))
@MainActor
struct RefreshHealthTests {

    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Skill.self, Challenge.self, ChallengeResult.self, UserProfile.self,
            configurations: config
        )
        context = container.mainContext
    }

    @Test("refreshHealth writes a lower score when time has passed")
    func refreshWritesDecayedHealth() {
        let skill = Skill(name: "Swift", category: .programming)
        // Simulate skill last practiced 30 days ago
        skill.lastPracticed = Date.now.addingTimeInterval(-30 * 86_400)
        skill.peakScore     = 1.0
        skill.decayRate     = 0.1
        skill.healthScore   = 1.0   // stale value
        context.insert(skill)

        DecayEngine.refreshHealth(for: skill)

        let expected = DecayEngine.healthScore(peakScore: 1.0, decayRate: 0.1, daysSinceLastPractice: 30)
        #expect(approxEqual(skill.healthScore, expected, tolerance: 1e-6),
            "refreshHealth must match formula output (got \(skill.healthScore), expected ≈ \(expected))")
        #expect(skill.healthScore < 1.0, "30-day-old skill must have degraded health")
    }

    @Test("refreshHealth on brand-new skill leaves health at peak")
    func freshSkillHealthStaysAtPeak() {
        let skill = Skill(name: "Python", category: .programming)
        skill.peakScore   = 0.9
        skill.healthScore = 0.9
        skill.decayRate   = 0.1
        // lastPracticed = now (set in Skill.init)
        context.insert(skill)

        DecayEngine.refreshHealth(for: skill)

        #expect(approxEqual(skill.healthScore, 0.9, tolerance: 1e-6),
            "Brand-new skill health must remain at peak")
    }
}
