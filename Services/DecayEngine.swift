import Foundation
import SwiftData

// MARK: - Decay Engine

/// Pure-function engine implementing the modified Ebbinghaus forgetting curve.
///
/// ## Algorithm
/// ```
/// healthScore(t) = peakScore × e^(−λ × t)
/// ```
/// where `λ` = `decayRate` and `t` = days since last practice.
///
/// ## Design
/// All **math functions** are `static` and take only `Double`/`Int` arguments —
/// no SwiftData dependency, making them trivially unit-testable.
///
/// The **skill-mutation** methods (`apply`, `refreshHealth`) are `@MainActor`
/// because `@Model` objects must be accessed on the `ModelContext` actor.
enum DecayEngine {

    // MARK: - Constants

    /// Initial decay rate assigned to every new skill (λ₀).
    static let defaultDecayRate: Double = 0.1

    /// Floor for λ — a very well-retained skill still decays a little.
    static let minDecayRate: Double = 0.01

    /// Ceiling for λ — even the most forgotten skill can't decay faster than this.
    static let maxDecayRate: Double = 1.0

    /// Health fraction at which a review is scheduled (maps to `.sdtHealthHealthy`).
    static let reviewTargetFraction: Double = 0.7

    /// Base XP awarded for a correct answer before difficulty/confidence bonuses.
    static let baseXP: Int = 10

    /// Maximum boost applied to `peakScore` per correct answer.
    static let peakBoostMax: Double = 0.05

    // MARK: - Pure Math

    /// Current health score using the modified Ebbinghaus formula.
    ///
    /// - Parameters:
    ///   - peakScore: Historical ceiling, in 0…1.
    ///   - decayRate: Per-skill decay constant λ (must be > 0).
    ///   - daysSinceLastPractice: Elapsed time in fractional days (must be ≥ 0).
    /// - Returns: Health in 0…`peakScore`.
    static func healthScore(
        peakScore: Double,
        decayRate: Double,
        daysSinceLastPractice: Double
    ) -> Double {
        guard decayRate > 0, daysSinceLastPractice >= 0 else { return peakScore }
        return peakScore * exp(-decayRate * daysSinceLastPractice)
    }

    /// Adjusts λ based on how strongly the user retained the material.
    ///
    /// `retentionSignal` comes from `ChallengeResult.retentionSignal` (0…1):
    /// - Signal 1.0 → rate decreases 10% (material is durable)
    /// - Signal 0.5 → rate unchanged
    /// - Signal 0.0 → rate increases 10% (material is fragile)
    ///
    /// Result is clamped to `[minDecayRate, maxDecayRate]`.
    static func adjustedDecayRate(current: Double, retentionSignal: Double) -> Double {
        let signal = max(0, min(1, retentionSignal))
        let adjusted = current * (1 + (0.5 - signal) * 0.2)
        return max(minDecayRate, min(maxDecayRate, adjusted))
    }

    /// Days until health drops to `targetFraction × peakScore`.
    ///
    /// Derived by solving `target = peak × e^(−λt)` for `t`:
    /// ```
    /// t = −ln(targetFraction) / λ
    /// ```
    /// - Returns: `nil` when inputs are degenerate (zero peak, zero rate, or target ≥ peak).
    static func daysUntilReview(
        decayRate: Double,
        peakScore: Double,
        targetFraction: Double = reviewTargetFraction
    ) -> Double? {
        guard peakScore > 0, decayRate > 0 else { return nil }
        guard targetFraction > 0, targetFraction < 1 else { return nil }
        return -log(targetFraction) / decayRate
    }

    /// XP awarded for answering a challenge.
    ///
    /// Correct answer: `baseXP × difficulty + confidenceBonus` where
    /// confidenceBonus is 0 / 5 / 10 for low / medium / high.
    /// Wrong answer: always 0.
    static func xpReward(
        isCorrect: Bool,
        difficulty: Int,
        confidence: ConfidenceRating
    ) -> Int {
        guard isCorrect else { return 0 }
        let clampedDifficulty = max(1, min(5, difficulty))
        let confidenceBonus: Int = switch confidence {
            case .low:    0
            case .medium: 5
            case .high:   10
        }
        return baseXP * clampedDifficulty + confidenceBonus
    }

    // MARK: - Skill Mutations

    /// Applies a completed challenge result to a skill.
    ///
    /// Call this on the `@MainActor` immediately after the user answers.
    /// Mutates: `decayRate`, `totalPracticeCount`, `correctCount`, `peakScore`,
    /// `healthScore`, `lastPracticed`, `nextReviewDate`, `streakDays`.
    @MainActor
    static func apply(result: ChallengeResult, to skill: Skill) {
        let now = Date.now

        // 1. Update streak before overwriting lastPracticed.
        updateStreak(skill: skill, now: now)

        // 2. Adjust decay rate based on retention quality.
        skill.decayRate = adjustedDecayRate(
            current: skill.decayRate,
            retentionSignal: result.retentionSignal
        )

        // 3. Record the attempt.
        skill.totalPracticeCount += 1
        if result.isCorrect { skill.correctCount += 1 }

        // 4. Correct answer raises the peak score (capped at 1.0).
        //    The boost is scaled by retention signal — a fragile correct answer
        //    earns a smaller ceiling lift than a fast, confident one.
        if result.isCorrect {
            skill.peakScore = min(1.0, skill.peakScore + peakBoostMax * result.retentionSignal)
        }

        // 5. Practising resets the decay clock (t = 0 → health = peak).
        skill.healthScore = skill.peakScore
        skill.lastPracticed = now

        // 6. Schedule the next spaced-repetition review.
        let days = daysUntilReview(
            decayRate: skill.decayRate,
            peakScore: skill.peakScore
        ) ?? 1.0
        skill.nextReviewDate = now.addingTimeInterval(days * 86_400)
    }

    /// Recalculates `healthScore` using elapsed time since last practice.
    ///
    /// Call this on app launch / foreground transition to keep health current
    /// without requiring a new challenge attempt.
    @MainActor
    static func refreshHealth(for skill: Skill) {
        skill.healthScore = healthScore(
            peakScore: skill.peakScore,
            decayRate: skill.decayRate,
            daysSinceLastPractice: skill.daysSinceLastPractice
        )
    }

    // MARK: - Private Helpers

    @MainActor
    private static func updateStreak(skill: Skill, now: Date) {
        let calendar = Calendar.current
        let lastDay  = calendar.startOfDay(for: skill.lastPracticed)
        let today    = calendar.startOfDay(for: now)
        let diff     = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        switch diff {
        case 0:
            break               // same calendar day — streak unchanged
        case 1:
            skill.streakDays += 1   // consecutive day ✓
        default:
            skill.streakDays = 1    // gap detected — reset
        }
    }
}
