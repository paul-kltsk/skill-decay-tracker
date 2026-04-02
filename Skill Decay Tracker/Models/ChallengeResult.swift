import Foundation
import SwiftData

// MARK: - Confidence Rating

/// The user's self-reported confidence after answering a challenge.
///
/// Used by ``DecayEngine`` alongside correctness and response time to
/// adjust `decayRate` — low confidence on a correct answer is treated
/// as fragile retention.
///
/// `Sendable` — safely crosses actor boundaries when computing decay adjustments.
enum ConfidenceRating: Int, Codable, CaseIterable, Sendable {
    case low    = 1
    case medium = 2
    case high   = 3

    var displayName: String {
        switch self {
        case .low:    "Not sure"
        case .medium: "Pretty sure"
        case .high:   "Very confident"
        }
    }

    var systemImage: String {
        switch self {
        case .low:    "face.dashed"
        case .medium: "face.smiling"
        case .high:   "face.smiling.inverse"
        }
    }
}

// MARK: - ChallengeResult

/// A single recorded attempt at a ``Challenge`` during a practice session.
///
/// ``DecayEngine`` reads `isCorrect`, `responseTime`, and `confidenceRating`
/// to update the parent ``Skill``'s `decayRate` and `nextReviewDate`.
///
/// **Retention signal rules:**
/// - Fast + correct + high confidence → strong retention → lower `decayRate`
/// - Slow + correct + low confidence → fragile retention → slight `decayRate` increase
/// - Incorrect → weaker retention → increase `decayRate` + earlier review
@Model
final class ChallengeResult {

    // MARK: Identity

    var id: UUID = UUID()
    var practiceDate: Date = Date.now

    // MARK: Answer Data

    /// Whether the user's answer matched the correct answer.
    var isCorrect: Bool = false
    /// Time the user took to submit an answer, in seconds.
    var responseTime: TimeInterval = 0
    /// The user's self-reported confidence level.
    var confidenceRating: ConfidenceRating = ConfidenceRating.medium
    /// The raw answer string the user submitted.
    var userAnswer: String = ""

    // MARK: Session Context

    /// Index of this result within its practice session (0-based).
    var sessionPosition: Int = 0

    // MARK: Relationships

    /// The challenge this result belongs to (many-to-one, inverse of `Challenge.results`).
    var challenge: Challenge?

    // MARK: Init

    init(
        isCorrect: Bool,
        responseTime: TimeInterval,
        confidenceRating: ConfidenceRating,
        userAnswer: String,
        sessionPosition: Int = 0
    ) {
        self.id                 = UUID()
        self.practiceDate       = Date.now
        self.isCorrect          = isCorrect
        self.responseTime       = responseTime
        self.confidenceRating   = confidenceRating
        self.userAnswer         = userAnswer
        self.sessionPosition    = sessionPosition
    }

    // MARK: Computed Helpers

    /// A combined retention signal in 0…1 used by the decay engine.
    ///
    /// Blends correctness, response speed, and self-reported confidence.
    /// Fast + correct + confident → near 1.0. Wrong → near 0.0.
    var retentionSignal: Double {
        guard isCorrect else { return 0.0 }

        // Speed score: 0…1 where ≤10 s = 1.0 and ≥120 s = 0.0
        let speedScore = max(0, min(1, 1 - (responseTime - 10) / 110))

        // Confidence score: map 1…3 → 0.33…1.0
        let confidenceScore = Double(confidenceRating.rawValue) / 3.0

        // Weighted blend: correctness implied (guard above), speed 40%, confidence 60%
        return speedScore * 0.4 + confidenceScore * 0.6
    }
}
