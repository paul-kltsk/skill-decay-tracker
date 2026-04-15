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

    var id: UUID = UUID()
    var name: String = ""
    /// The category determines accent color and SF Symbol icon (see `SkillCategory`).
    var category: SkillCategory = SkillCategory.custom
    var createdAt: Date = Date.now

    /// Optional free-text context the user provides when adding the skill.
    ///
    /// Injected verbatim into AI generation and evaluation prompts so that
    /// questions are tailored to the user's specific goals or environment.
    ///
    /// Examples: "Django project", "JLPT N3 prep", "Interview preparation"
    var context: String = ""

    // MARK: Health & Decay

    /// Current health in the range 0…1. Written by `DecayEngine` after each calculation.
    var healthScore: Double = 1.0
    /// Peak health ever recorded for this skill — used as the ceiling in the decay formula.
    var peakScore: Double = 1.0
    /// Per-skill decay rate (λ). Starts at 0.1; decreases on success, increases on failure.
    var decayRate: Double = 0.1
    /// The date the user last completed any practice session for this skill.
    var lastPracticed: Date = Date.now
    /// The next date the spaced-repetition algorithm schedules a review.
    var nextReviewDate: Date = Date.now

    // MARK: Progress

    /// Consecutive days the user has practiced this skill.
    var streakDays: Int = 0
    /// Lifetime number of challenges answered for this skill.
    var totalPracticeCount: Int = 0
    /// Lifetime number of correctly answered challenges.
    var correctCount: Int = 0

    // MARK: Relationships

    /// Pre-generated and historical challenges for this skill.
    /// Deleting a Skill cascades to all its Challenges (and their Results).
    @Relationship(deleteRule: .cascade, inverse: \Challenge.skill)
    var challenges: [Challenge]?

    /// The group this skill belongs to, or `nil` if ungrouped.
    var group: SkillGroup?

    /// Explicit difficulty override set when the user accepts a difficulty-adjustment suggestion.
    ///
    /// - `nil` — no override; `suggestedDifficulty` (accuracy-based) is used for AI prompts.
    /// - `1…5` — overrides the auto-computed value until the user resets or a new suggestion is accepted.
    var overrideDifficulty: Int?

    /// Number of questions chosen by the user when creating this skill (5, 7, 10, or 15).
    ///
    /// Used as the session target for Deep Dive. Free users are capped at 5 regardless of this value;
    /// when Pro is restored the original value is used automatically.
    var questionCount: Int = 5

    // MARK: Init

    init(
        name: String,
        category: SkillCategory,
        context: String = "",
        decayRate: Double = 0.1
    ) {
        self.id               = UUID()
        self.name             = name
        self.category         = category
        self.context          = context
        self.createdAt        = Date.now
        self.healthScore      = 1.0
        self.peakScore        = 1.0
        self.decayRate        = decayRate
        self.lastPracticed    = Date.now
        self.nextReviewDate   = Date.now
        self.streakDays       = 0
        self.totalPracticeCount = 0
        self.correctCount     = 0
        self.challenges         = []
        self.group              = nil
        self.overrideDifficulty = nil
    }

    // MARK: Computed Helpers

    /// Calendar days since the user last practiced this skill.
    var daysSinceLastPractice: Double {
        Date.now.timeIntervalSince(lastPracticed) / 86_400
    }

    /// Accuracy-based difficulty hint for AI prompts (1–4).
    ///
    /// Auto-computed from lifetime accuracy — no manual tuning needed.
    /// Overridden by `overrideDifficulty` when the user accepts a difficulty suggestion.
    var suggestedDifficulty: Int {
        guard let accuracy = accuracyRate else { return 3 }
        switch accuracy {
        case 0.9...: return 4
        case 0.7...: return 3
        case 0.5...: return 2
        default:     return 1
        }
    }

    /// Difficulty level used in AI prompts.
    ///
    /// Returns the explicit override if the user has accepted a difficulty suggestion,
    /// otherwise falls back to the accuracy-based `suggestedDifficulty`.
    var effectiveDifficulty: Int {
        overrideDifficulty ?? suggestedDifficulty
    }

    /// Accuracy rate in the range 0…1, or `nil` if never practiced.
    var accuracyRate: Double? {
        guard totalPracticeCount > 0 else { return nil }
        return Double(correctCount) / Double(totalPracticeCount)
    }

    /// Challenges available to show in a practice session.
    ///
    /// Includes two or three categories, sorted so weaknesses are tackled first:
    /// 1. **Review-due** — previously answered incorrectly / with low confidence,
    ///    whose `nextReviewDate` has passed. Shown first as priority repetitions.
    /// 2. **Fresh** — never been shown (`isUsed == false`).
    /// 3. **Mastered (decay-reactivated)** — included only when `healthScore < 0.5`
    ///    (skill is Fading or worse). Even "mastered" knowledge fades when a skill
    ///    hasn't been practised for a long time; reintroducing these questions lets
    ///    the user rebuild retention before health drops further.
    var pendingChallenges: [Challenge] {
        let all = challenges ?? []
        let now = Date.now
        let reviewDue = all.filter { $0.isUsed && ($0.nextReviewDate ?? .distantFuture) <= now }
        let fresh     = all.filter { !$0.isUsed }

        // When the skill is significantly decayed, surface previously-mastered questions
        // so the user can re-consolidate forgotten material.
        if healthScore < 0.5 {
            let mastered = all.filter { $0.isUsed && $0.nextReviewDate == nil }
            return reviewDue + fresh + mastered
        }

        return reviewDue + fresh   // review-due first → tackle weaknesses before new material
    }
}
