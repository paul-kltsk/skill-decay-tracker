import Foundation
import SwiftData

// MARK: - Evaluation Result

/// The result of asking Claude to evaluate a user's answer.
struct EvaluationResult: Sendable {
    /// Whether the user's answer was judged correct.
    let isCorrect: Bool
    /// Short natural-language feedback to show the user.
    let feedback: String
    /// Confidence level inferred from response quality and timing.
    let inferredConfidence: ConfidenceRating
}

// MARK: - Challenge DTO (AI response)

/// JSON shape Claude returns for each generated challenge.
private struct ChallengeDTO: Decodable, Sendable {
    let type: String
    let question: String
    let options: [String]?
    let correctAnswer: String
    let explanation: String
    let difficulty: Int?
    let timeLimitSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case type, question, options, explanation, difficulty
        case correctAnswer    = "correct_answer"
        case timeLimitSeconds = "time_limit_seconds"
    }
}

// MARK: - Evaluation DTO (AI response)

/// JSON shape Claude returns when evaluating an answer.
private struct EvaluationDTO: Decodable, Sendable {
    let isCorrect: Bool
    let feedback: String
    let confidenceHint: String?

    enum CodingKeys: String, CodingKey {
        case isCorrect      = "is_correct"
        case feedback
        case confidenceHint = "confidence_hint"
    }
}

// MARK: - Model IDs

private enum ClaudeModel {
    /// High-quality reasoning — used for challenge generation.
    static let generation = "claude-sonnet-4-20250514"
    /// Fast and cost-efficient — used for answer evaluation.
    static let evaluation = "claude-haiku-4-5-20251001"
}

// MARK: - AI Service

/// High-level actor for AI-driven challenge generation and answer evaluation.
///
/// Uses ``ClaudeAPIClient`` for HTTP calls and falls back to offline templates
/// when the API is unreachable or the key is missing.
///
/// **Typical usage:**
/// ```swift
/// let challenges = try await AIService.shared.generateChallenges(for: skill, count: 3)
/// let result     = try await AIService.shared.evaluateAnswer(challenge: c, userAnswer: "Swift")
/// ```
actor AIService {

    // MARK: Singleton

    static let shared = AIService()

    // MARK: Dependencies

    private let client: ClaudeAPIClient

    // MARK: Init

    init(client: ClaudeAPIClient = .shared) {
        self.client = client
    }

    // MARK: - Challenge Generation

    /// Generates `count` micro-challenges for the given skill using Claude.
    ///
    /// Falls back to offline template challenges on network or API-key errors.
    ///
    /// - Parameters:
    ///   - skill: The ``Skill`` for which to generate challenges.
    ///   - count: Number of challenges requested (default 3).
    /// - Returns: Unsaved ``Challenge`` objects ready to insert into SwiftData.
    func generateChallenges(for skill: Skill, count: Int = 3) async throws -> [Challenge] {
        let prompt = generationPrompt(
            skillName: skill.name,
            category:  skill.category.rawValue,
            difficulty: skill.suggestedDifficulty,
            count: count
        )
        do {
            let raw  = try await client.send(model: ClaudeModel.generation,
                                              maxTokens: 1024,
                                              prompt: prompt)
            let dtos = try parseChallengeDTOs(from: raw)
            return dtos.map { mapToChallenge($0) }
        } catch let error as APIError where error.allowsFallback {
            return FallbackTemplates.challenges(for: skill, count: count)
        }
    }

    // MARK: - Answer Evaluation

    /// Evaluates whether `userAnswer` is correct for `challenge`.
    ///
    /// Objective types (`.multipleChoice`, `.trueFalse`) are evaluated locally
    /// without an API call. Subjective types use Claude Haiku.
    ///
    /// - Parameters:
    ///   - challenge: The challenge that was presented.
    ///   - userAnswer: The answer string supplied by the user.
    ///   - responseTime: How long the user took; used to infer confidence.
    func evaluateAnswer(
        challenge: Challenge,
        userAnswer: String,
        responseTime: TimeInterval = 0
    ) async throws -> EvaluationResult {
        // Fast-path: objective types evaluated locally
        if challenge.type == .multipleChoice || challenge.type == .trueFalse {
            let correct = userAnswer
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(
                    challenge.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                ) == .orderedSame
            let confidence = inferredConfidence(responseTime: responseTime,
                                                timeLimitSeconds: challenge.timeLimitSeconds,
                                                isCorrect: correct)
            let feedback = correct
                ? challenge.explanation
                : "Correct answer: \(challenge.correctAnswer). \(challenge.explanation)"
            return EvaluationResult(isCorrect: correct,
                                    feedback: feedback,
                                    inferredConfidence: confidence)
        }

        // Subjective types — ask Claude Haiku
        let prompt = evaluationPrompt(challenge: challenge, userAnswer: userAnswer)
        let raw    = try await client.send(model: ClaudeModel.evaluation,
                                            maxTokens: 256,
                                            prompt: prompt)
        let dto    = try parseEvaluationDTO(from: raw)
        let confidence = parseConfidence(dto.confidenceHint,
                                          responseTime: responseTime,
                                          timeLimitSeconds: challenge.timeLimitSeconds,
                                          isCorrect: dto.isCorrect)
        return EvaluationResult(isCorrect: dto.isCorrect,
                                feedback: dto.feedback,
                                inferredConfidence: confidence)
    }

    // MARK: - Prompt Builders

    private func generationPrompt(
        skillName: String,
        category: String,
        difficulty: Int,
        count: Int
    ) -> String {
        """
        You are an expert educator generating micro-challenges for a spaced-repetition learning app.
        Generate exactly \(count) challenges for the skill: "\(skillName)" (category: \(category)).
        Target difficulty: \(difficulty)/5.

        Rules:
        - Each challenge must take 1–3 minutes to answer.
        - Vary the type: prefer multiple_choice, but include at least one open_ended or fill_in_blank.
        - For multiple_choice: provide exactly 4 distinct options.
        - For true_false: options must be ["True", "False"].
        - The explanation must be educational, not just "correct/incorrect".
        - difficulty must be an integer 1–5.

        Respond ONLY with a valid JSON array. No markdown, no extra text. Schema:
        [
          {
            "type": "multiple_choice",
            "question": "...",
            "options": ["A", "B", "C", "D"],
            "correct_answer": "A",
            "explanation": "...",
            "difficulty": \(difficulty),
            "time_limit_seconds": 120
          }
        ]
        """
    }

    private func evaluationPrompt(challenge: Challenge, userAnswer: String) -> String {
        """
        Evaluate whether the user's answer is correct for this challenge.

        Challenge type: \(challenge.type.rawValue)
        Question: \(challenge.question)
        Correct answer: \(challenge.correctAnswer)
        User's answer: \(userAnswer)

        Respond ONLY with valid JSON. No markdown:
        {
          "is_correct": true,
          "feedback": "1–2 sentences explaining why correct or incorrect.",
          "confidence_hint": "high"
        }

        confidence_hint must be one of: "low", "medium", "high".
        Base it on how complete and precise the user's answer is.
        """
    }

    // MARK: - JSON Parsing

    private func parseChallengeDTOs(from raw: String) throws -> [ChallengeDTO] {
        let json = extractJSON(from: raw)
        guard let data = json.data(using: .utf8) else {
            throw APIError.invalidJSON(raw: raw)
        }
        do {
            return try JSONDecoder().decode([ChallengeDTO].self, from: data)
        } catch {
            throw APIError.invalidJSON(raw: json)
        }
    }

    private func parseEvaluationDTO(from raw: String) throws -> EvaluationDTO {
        let json = extractJSON(from: raw)
        guard let data = json.data(using: .utf8) else {
            throw APIError.invalidJSON(raw: raw)
        }
        do {
            return try JSONDecoder().decode(EvaluationDTO.self, from: data)
        } catch {
            throw APIError.invalidJSON(raw: json)
        }
    }

    /// Strips markdown code-fence wrappers that Claude sometimes emits.
    private func extractJSON(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            let lines = result.components(separatedBy: "\n")
            result = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - DTO → Model Mapping

    private func mapToChallenge(_ dto: ChallengeDTO) -> Challenge {
        Challenge(
            type:             ChallengeType(rawValue: dto.type) ?? .multipleChoice,
            question:         dto.question,
            options:          dto.options ?? [],
            correctAnswer:    dto.correctAnswer,
            explanation:      dto.explanation,
            difficulty:       max(1, min(5, dto.difficulty ?? 3)),
            timeLimitSeconds: dto.timeLimitSeconds ?? 120
        )
    }

    // MARK: - Confidence Inference

    private func inferredConfidence(
        responseTime: TimeInterval,
        timeLimitSeconds: Int,
        isCorrect: Bool
    ) -> ConfidenceRating {
        guard isCorrect else { return .low }
        let ratio = responseTime / Double(max(timeLimitSeconds, 1))
        switch ratio {
        case ..<0.33: return .high
        case ..<0.66: return .medium
        default:      return .low
        }
    }

    private func parseConfidence(
        _ hint: String?,
        responseTime: TimeInterval,
        timeLimitSeconds: Int,
        isCorrect: Bool
    ) -> ConfidenceRating {
        switch hint?.lowercased() {
        case "high":   return .high
        case "medium": return .medium
        case "low":    return .low
        default:       return inferredConfidence(responseTime: responseTime,
                                                  timeLimitSeconds: timeLimitSeconds,
                                                  isCorrect: isCorrect)
        }
    }
}

// MARK: - Skill Helper (private to this file)

private extension Skill {
    /// Suggested difficulty for new challenges, based on past accuracy.
    var suggestedDifficulty: Int {
        guard let accuracy = accuracyRate else { return 3 }
        switch accuracy {
        case 0.9...: return 4
        case 0.7...: return 3
        case 0.5...: return 2
        default:     return 1
        }
    }
}

// MARK: - Fallback Templates

/// Generates reflection-based offline challenges when the API is unavailable.
private enum FallbackTemplates {

    static func challenges(for skill: Skill, count: Int) -> [Challenge] {
        let all: [Challenge] = [
            Challenge(
                type: .multipleChoice,
                question: "How would you rate your current understanding of \(skill.name)?",
                options: [
                    "Struggling — needs urgent review",
                    "Shaky — basic concepts unclear",
                    "Solid — comfortable with fundamentals",
                    "Strong — can explain it to others",
                ],
                correctAnswer: "Strong — can explain it to others",
                explanation: "Honest self-assessment calibrates your spaced-repetition schedule.",
                difficulty: 1,
                timeLimitSeconds: 60
            ),
            Challenge(
                type: .trueFalse,
                question: "I can explain the core concept of \(skill.name) in plain language without looking anything up.",
                options: ["True", "False"],
                correctAnswer: "True",
                explanation: "Explaining a skill simply is the strongest signal of genuine understanding.",
                difficulty: 2,
                timeLimitSeconds: 60
            ),
            Challenge(
                type: .openEnded,
                question: "Describe the most important thing you know about \(skill.name) and one area where you still feel uncertain.",
                options: [],
                correctAnswer: "",
                explanation: "Writing about what you know — and don't know — reinforces memory more than passive review.",
                difficulty: 3,
                timeLimitSeconds: 180
            ),
        ]
        return Array(all.prefix(count))
    }
}
