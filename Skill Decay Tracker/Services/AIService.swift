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

// MARK: - Breadth Analysis DTOs (AI response)

/// One sub-skill suggestion returned by the breadth-analysis prompt.
private struct SubSkillDTO: Decodable, Sendable {
    let name: String
    let category: String
}

/// Top-level wrapper for the breadth-analysis response.
private struct SkillBreadthDTO: Decodable, Sendable {
    let subSkills: [SubSkillDTO]
}

// MARK: - Model IDs

private enum ClaudeModel {
    /// High-quality generation model — used for challenge generation.
    static let generation = "claude-sonnet-4-6"
    /// Fast and cost-efficient — used for answer evaluation and breadth analysis.
    static let evaluation = "claude-haiku-4-5-20251001"
}

// Note: OpenAI and Gemini model IDs are stored in AIProvider (generationModelID / evalModelID).

// MARK: - AI Service

/// High-level actor for AI-driven challenge generation and answer evaluation.
///
/// Routes requests to the active provider (Claude, OpenAI, or Gemini) based on
/// `AIProvider.persisted`. Falls back to offline templates when the API is
/// unreachable or the key is missing.
///
/// **Typical usage:**
/// ```swift
/// let challenges = try await AIService.shared.generateChallenges(for: skill, count: 3)
/// let result     = try await AIService.shared.evaluateAnswer(challenge: c, userAnswer: "Swift")
/// ```
actor AIService {

    // MARK: Singleton

    static let shared = AIService()

    // MARK: Init

    init() {}

    // MARK: - Locale

    /// The human-readable language name + BCP-47 code for the current device locale,
    /// e.g. "Russian (ru)" or "Japanese (ja)".  Injected into every AI prompt so that
    /// generated text (questions, feedback, explanations) matches the app's language.
    private var promptLanguage: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        return "\(name) (\(code))"
    }

    // MARK: - Provider Dispatch

    /// Sends `prompt` to whichever provider is currently selected in Settings.
    ///
    /// **Routing logic:**
    /// 1. If the user has stored a personal API key for the selected provider
    ///    → uses the direct client (zero latency overhead, user pays their own account).
    /// 2. If no personal key is present
    ///    → routes through the SDT proxy server (`sdtapi.mooo.com`), which uses
    ///    the developer's API keys. Works in all regions without VPN.
    ///
    /// - Parameters:
    ///   - isGeneration: `true` → use the provider's higher-quality generation model;
    ///                   `false` → use the faster evaluation model.
    ///   - maxTokens: Token budget for the response.
    ///   - prompt: The full user-turn prompt.
    private func sendPrompt(isGeneration: Bool, maxTokens: Int, prompt: String) async throws -> String {
        let provider = AIProvider.persisted

        // Resolve model IDs once — same whether going direct or through proxy.
        let model: String
        switch (provider, isGeneration) {
        case (.claude, true):  model = ClaudeModel.generation
        case (.claude, false): model = ClaudeModel.evaluation
        default:               model = isGeneration ? provider.generationModelID : provider.evalModelID
        }

        // Route: personal key present → direct; missing → proxy.
        if ProviderKeychain.has(for: provider) {
            switch provider {
            case .claude:
                return try await ClaudeAPIClient.shared.send(model: model,
                                                             maxTokens: maxTokens,
                                                             prompt: prompt)
            case .openai:
                return try await OpenAIClient.shared.send(model: model,
                                                          maxTokens: maxTokens,
                                                          prompt: prompt)
            case .gemini:
                return try await GeminiClient.shared.send(model: model,
                                                          maxTokens: maxTokens,
                                                          prompt: prompt)
            }
        } else {
            return try await ProxyAPIClient.shared.send(provider: provider,
                                                        model: model,
                                                        maxTokens: maxTokens,
                                                        prompt: prompt)
        }
    }

    // MARK: - Token Budget

    /// Calculates a safe output token budget for challenge generation.
    ///
    /// Each question needs ~300 tokens (question + 4 options + answer + explanation + metadata).
    /// Base overhead covers the JSON array wrapper and any prompt reflection: ~200 tokens.
    /// A 30 % safety buffer absorbs verbose explanations without truncating the response.
    ///
    /// Examples: 5 q → 2 210 tokens · 10 q → 4 160 tokens · 15 q → 6 110 tokens
    private func generationTokenBudget(for count: Int) -> Int {
        Int(Double(200 + 300 * count) * 1.3)
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
            difficulty: skill.effectiveDifficulty,
            context:   skill.context,
            count: count
        )
        do {
            let raw  = try await sendPrompt(isGeneration: true, maxTokens: generationTokenBudget(for: count), prompt: prompt)
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

        // Subjective types — ask AI provider
        let prompt = evaluationPrompt(challenge: challenge, userAnswer: userAnswer)
        let raw    = try await sendPrompt(isGeneration: false, maxTokens: 256, prompt: prompt)
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
        context: String,
        count: Int
    ) -> String {
        let contextLine = context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\nUser context: \(context.trimmingCharacters(in: .whitespacesAndNewlines))"
        return """
        You are an expert educator generating knowledge-testing challenges for a spaced-repetition learning app.
        Generate exactly \(count) challenges that TEST THE USER'S KNOWLEDGE of: "\(skillName)" (category: \(category)).\(contextLine)
        Target difficulty: \(difficulty)/5.
        IMPORTANT: Write all questions, options, and explanations in \(promptLanguage). Do not use any other language.

        Rules:
        - Questions must test FACTUAL KNOWLEDGE, comprehension, or application of the topic — not self-awareness or self-rating.
        - FORBIDDEN question types: "How would you rate your understanding?", "Can you explain X?" as True/False, any self-assessment. These are strictly prohibited.
        - For multiple_choice: write a concrete factual question with exactly 4 plausible but distinct options; only one is correct.
        - For true_false: state a specific factual claim about the topic that is clearly true or false (e.g. "ARC increments an object's retain count when a strong reference is created"). Options must be ["True", "False"].
        - For open_ended or fill_in_blank: ask the user to explain a mechanism, predict output, or fill in a missing term/keyword.
        - Vary the type: prefer multiple_choice, but include at least one open_ended or fill_in_blank.
        - Each challenge must take 1–3 minutes to answer.
        - The explanation must be educational — explain WHY the answer is correct, not just state it.
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
        let skillContext = challenge.skill?.context.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let contextLine = skillContext.isEmpty ? "" : "\nSkill context: \(skillContext)"
        return """
        Evaluate whether the user's answer is correct for this challenge.\(contextLine)
        Write the feedback field in \(promptLanguage).

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

    // MARK: - Skill Breadth Analysis

    /// Checks whether `name` is broad enough to split into sub-skills.
    ///
    /// Uses the faster evaluation model and returns up to 4 `SkillSuggestion` objects.
    /// Returns an empty array when the topic is already specific or on any error.
    func analyzeSkillBreadth(name: String, context: String = "", category: SkillCategory) async -> [SkillSuggestion] {
        let prompt = breadthPrompt(name: name, context: context)
        let raw: String
        do {
            raw = try await sendPrompt(isGeneration: false, maxTokens: 256, prompt: prompt)
        } catch {
            return []
        }
        let json = extractJSON(from: raw)
        guard let data = json.data(using: .utf8) else { return [] }
        do {
            let dto = try JSONDecoder().decode(SkillBreadthDTO.self, from: data)
            return dto.subSkills.compactMap { sub in
                let cat = SkillCategory(rawValue: sub.category) ?? category
                return SkillSuggestion(name: sub.name, category: cat)
            }
        } catch {
            return []
        }
    }

    private func breadthPrompt(name: String, context: String = "") -> String {
        let contextLine = context.isEmpty
            ? ""
            : "\n        The user's stated goal or context: \"\(context)\""
        return """
        You are a learning expert helping a user set up a spaced-repetition practice app.
        The user wants to learn: "\(name)"\(contextLine)

        Decide if this topic is TOO BROAD to practice effectively without narrowing it down.

        TOO BROAD — suggest 3-4 focused sub-skills:
        - Entire programming languages: "Swift", "Python", "JavaScript", "Kotlin", "Go"
        - Entire human languages: "Spanish", "Japanese", "French"
        - Vast domains: "Machine Learning", "iOS Development", "Web Development", "Design"

        SPECIFIC ENOUGH — return empty subSkills:
        - A named feature or concept: "Swift ARC", "React Hooks", "Git Rebase", "Spanish Grammar"
        - A concrete goal already mentioned in context
        - Anything the user can realistically practice in focused sessions as-is

        If the user provided a goal/context, the topic is already specific enough — return empty subSkills.
        Write sub-skill names in \(promptLanguage).

        Respond ONLY with valid JSON, no markdown:
        {"subSkills": [{"name": "Swift — Memory Management", "category": "programming"}]}

        Valid categories: programming, language, tool, concept, custom
        If the topic is already specific: {"subSkills": []}
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
            options:          (dto.options ?? []).shuffled(),
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
