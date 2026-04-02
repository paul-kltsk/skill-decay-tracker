import Foundation
import SwiftData

// MARK: - Challenge Type

/// The interaction format of an AI-generated micro-challenge.
///
/// `Sendable` — safe to pass across actor boundaries (e.g. from a background
/// fetch task to the `@MainActor` view layer).
enum ChallengeType: String, Codable, CaseIterable, Sendable {
    case multipleChoice  = "multiple_choice"
    case trueFalse       = "true_false"
    case openEnded       = "open_ended"
    case fillInTheBlank  = "fill_in_blank"
    case codeCompletion  = "code_completion"

    var displayName: String {
        switch self {
        case .multipleChoice: "Multiple Choice"
        case .trueFalse:      "True / False"
        case .openEnded:      "Open Ended"
        case .fillInTheBlank: "Fill in the Blank"
        case .codeCompletion: "Code Completion"
        }
    }

    var systemImage: String {
        switch self {
        case .multipleChoice:  "list.bullet.circle"
        case .trueFalse:       "checkmark.circle"
        case .openEnded:       "text.bubble"
        case .fillInTheBlank:  "square.and.pencil"
        case .codeCompletion:  "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Challenge

/// An AI-generated micro-challenge (2–3 min) associated with one ``Skill``.
///
/// Challenges are pre-generated in batches of 3 by ``AIService`` during
/// background fetch and stored here until presented to the user.
///
/// **Relationship chain:** `Skill` →(cascade) `Challenge` →(cascade) `ChallengeResult`
@Model
final class Challenge {

    // MARK: Identity

    var id: UUID = UUID()
    var createdAt: Date = Date.now

    // MARK: Content

    var type: ChallengeType = .multipleChoice
    /// The question or prompt shown to the user.
    var question: String = ""
    /// Answer choices for `.multipleChoice` and `.trueFalse`; empty for other types.
    var options: [String] = []
    /// The canonical correct answer string — used by `AIService` for evaluation.
    var correctAnswer: String = ""
    /// Explanation shown after the user answers, regardless of correctness.
    var explanation: String = ""
    /// Difficulty on a 1–5 scale. Used to adapt future challenge generation.
    var difficulty: Int

    // MARK: State

    /// `true` once this challenge has been presented to the user in any session.
    var isUsed: Bool
    /// Time limit in seconds. `nil` means no limit (open-ended).
    var timeLimitSeconds: Int

    /// Spaced-repetition review date for this specific challenge.
    ///
    /// - `nil` — challenge has been mastered (correct + confident) or never attempted.
    /// - Past date — challenge is due for review (was answered incorrectly or with low confidence).
    ///
    /// Set by `PracticeViewModel.recordResult` after each answer:
    /// - Wrong → +1 day
    /// - Correct but low confidence → +2 days
    /// - Correct + medium/high confidence → `nil` (mastered, no re-review)
    var nextReviewDate: Date?

    // MARK: Relationships

    /// The skill this challenge belongs to (many-to-one, inverse of `Skill.challenges`).
    var skill: Skill?

    /// All results recorded each time this challenge was answered.
    /// Deleting a Challenge cascades to all its ChallengeResults.
    @Relationship(deleteRule: .cascade, inverse: \ChallengeResult.challenge)
    var results: [ChallengeResult]?

    // MARK: Init

    init(
        type: ChallengeType,
        question: String,
        options: [String] = [],
        correctAnswer: String,
        explanation: String,
        difficulty: Int = 3,
        timeLimitSeconds: Int = 120
    ) {
        self.id               = UUID()
        self.createdAt        = Date.now
        self.type             = type
        self.question         = question
        self.options          = options
        self.correctAnswer    = correctAnswer
        self.explanation      = explanation
        self.difficulty       = difficulty
        self.isUsed           = false
        self.timeLimitSeconds = timeLimitSeconds
        self.nextReviewDate   = nil
        self.results          = []
    }

    // MARK: Computed Helpers

    /// Whether the user has ever answered this challenge correctly.
    var wasEverAnsweredCorrectly: Bool {
        (results ?? []).contains { $0.isCorrect }
    }

    /// `true` when this challenge is scheduled for spaced-repetition review right now.
    var isDueForReview: Bool {
        guard let due = nextReviewDate else { return false }
        return due <= Date.now
    }

    /// Average response time across all recorded results.
    var averageResponseTime: TimeInterval? {
        let r = results ?? []
        guard !r.isEmpty else { return nil }
        return r.reduce(0) { $0 + $1.responseTime } / Double(r.count)
    }
}
