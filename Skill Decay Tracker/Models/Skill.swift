import Foundation
import SwiftData

// MARK: - Skill

/// A single learnable skill tracked in the user's knowledge portfolio.
///
/// Health decays over time following a modified Ebbinghaus forgetting curve:
/// ```
/// healthScore(t) = peakScore × e^(−decayRate × daysSinceLastPractice)
/// ```
/// `DecayEngine` owns the actual computation; this model only stores the
/// persisted state that the engine reads and writes.
@Model
final class Skill {

    // MARK: Identity

    var id: UUID
    var name: String
    /// The category determines accent color and SF Symbol icon (see `SkillCategory`).
    var category: SkillCategory
    var createdAt: Date

    // MARK: Health & Decay

    /// Current health in the range 0…1. Written by `DecayEngine` after each calculation.
    var healthScore: Double
    /// Peak health ever recorded for this skill — used as the ceiling in the decay formula.
    var peakScore: Double
    /// Per-skill decay rate (λ). Starts at 0.1; decreases on success, increases on failure.
    var decayRate: Double
    /// The date the user last completed any practice session for this skill.
    var lastPracticed: Date
    /// The next date the spaced-repetition algorithm schedules a review.
    var nextReviewDate: Date

    // MARK: Progress

    /// Consecutive days the user has practiced this skill.
    var streakDays: Int
    /// Lifetime number of challenges answered for this skill.
    var totalPracticeCount: Int
    /// Lifetime number of correctly answered challenges.
    var correctCount: Int

    // MARK: Relationships

    /// Pre-generated and historical challenges for this skill.
    /// Deleting a Skill cascades to all its Challenges (and their Results).
    @Relationship(deleteRule: .cascade, inverse: \Challenge.skill)
    var challenges: [Challenge]

    /// The group this skill belongs to, or `nil` if ungrouped.
    var group: SkillGroup?

    // MARK: Init

    init(
        name: String,
        category: SkillCategory,
        decayRate: Double = 0.1
    ) {
        self.id               = UUID()
        self.name             = name
        self.category         = category
        self.createdAt        = Date.now
        self.healthScore      = 1.0
        self.peakScore        = 1.0
        self.decayRate        = decayRate
        self.lastPracticed    = Date.now
        self.nextReviewDate   = Date.now
        self.streakDays       = 0
        self.totalPracticeCount = 0
        self.correctCount     = 0
        self.challenges       = []
        self.group            = nil
    }

    // MARK: Computed Helpers

    /// Calendar days since the user last practiced this skill.
    var daysSinceLastPractice: Double {
        Date.now.timeIntervalSince(lastPracticed) / 86_400
    }

    /// Accuracy rate in the range 0…1, or `nil` if never practiced.
    var accuracyRate: Double? {
        guard totalPracticeCount > 0 else { return nil }
        return Double(correctCount) / Double(totalPracticeCount)
    }

    /// Challenges available to show in a practice session.
    ///
    /// Includes two categories, sorted so review-due challenges appear first:
    /// 1. **Review-due** — previously answered incorrectly / with low confidence,
    ///    whose `nextReviewDate` has passed. Shown first as priority repetitions.
    /// 2. **Fresh** — never been shown (`isUsed == false`).
    ///
    /// Mastered challenges (`isUsed && nextReviewDate == nil`) are excluded.
    var pendingChallenges: [Challenge] {
        let now = Date.now
        let reviewDue = challenges.filter { $0.isUsed && ($0.nextReviewDate ?? .distantFuture) <= now }
        let fresh     = challenges.filter { !$0.isUsed }
        return reviewDue + fresh   // review-due first → tackled weaknesses before new material
    }
}
