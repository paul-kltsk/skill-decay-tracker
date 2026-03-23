import Foundation
import NaturalLanguage
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

// MARK: - Challenge Eval Context

/// Sendable snapshot of the ``Challenge`` properties required by ``AIService`` for evaluation.
///
/// Extract values from a ``Challenge`` on `@MainActor` **before** calling into the
/// `AIService` actor so that no `@Model` object crosses the actor boundary.
///
/// ```swift
/// // On @MainActor — extract scalars
/// let evalCtx = ChallengeEvalContext(from: challenge)
/// // Cross actor boundary — only Sendable values
/// let result = try await AIService.shared.evaluateAnswer(context: evalCtx, ...)
/// ```
struct ChallengeEvalContext: Sendable {
    let type: ChallengeType
    let question: String
    let correctAnswer: String
    let explanation: String
    let timeLimitSeconds: Int
    let skillContext: String

    /// Convenience initialiser — call on `@MainActor` where the `Challenge` is accessible.
    init(from challenge: Challenge) {
        type             = challenge.type
        question         = challenge.question
        correctAnswer    = challenge.correctAnswer
        explanation      = challenge.explanation
        timeLimitSeconds = challenge.timeLimitSeconds
        skillContext     = challenge.skill?.context.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
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
private struct EvaluationDTO: Sendable {
    let isCorrect: Bool
    let feedback: String
    let confidenceHint: String?
}

private extension EvaluationDTO {
    enum CodingKeys: String, CodingKey {
        case isCorrect      = "is_correct"
        case feedback
        case confidenceHint = "confidence_hint"
    }
}

nonisolated extension EvaluationDTO: Decodable {}

// MARK: - Breadth Analysis DTOs (AI response)

/// One sub-skill suggestion returned by the breadth-analysis prompt.
private struct SubSkillDTO: Sendable {
    let name: String
    let category: String
}

nonisolated extension SubSkillDTO: Decodable {}

/// Top-level wrapper for the breadth-analysis response.
private struct SkillBreadthDTO: Sendable {
    let subSkills: [SubSkillDTO]
}

nonisolated extension SkillBreadthDTO: Decodable {}

// MARK: - Model IDs

private enum ClaudeModel {
    /// Fast and cost-efficient — used for challenge generation.
    nonisolated static let generation = "claude-haiku-4-5-20251001"
    /// Fast and cost-efficient — used for answer evaluation and breadth analysis.
    nonisolated static let evaluation = "claude-haiku-4-5-20251001"
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
/// // Extract Sendable scalars on @MainActor before crossing into the actor
/// let challenges = try await AIService.shared.generateChallenges(
///     skillName: skill.name, category: skill.category.rawValue,
///     difficulty: skill.effectiveDifficulty, skillContext: skill.context, count: 3)
/// let ctx    = ChallengeEvalContext(from: challenge)
/// let result = try await AIService.shared.evaluateAnswer(context: ctx, userAnswer: "Swift")
/// ```
actor AIService {

    // MARK: Singleton

    static let shared = AIService()

    // MARK: Init

    init() {}

    // MARK: - Language Detection

    /// Detects the dominant language of `text` using on-device NLP.
    ///
    /// Returns a human-readable label + BCP-47 code, e.g. `"Russian (ru)"`.
    /// Injected into AI prompts so generated content matches the skill's language,
    /// not the device locale.  Falls back to `"English (en)"` when detection fails
    /// (very short text, mixed script, etc.).
    private func detectedLanguage(from text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let code = recognizer.dominantLanguage?.rawValue ?? "en"
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

    /// Generates `count` micro-challenges for a skill using the active AI provider.
    ///
    /// Extract all parameters from `Skill` on `@MainActor` before calling this method
    /// so that no `@Model` object crosses the actor boundary.
    ///
    /// - Parameters:
    ///   - skillName: Name of the skill (e.g. `"Swift ARC"`).
    ///   - category: Skill category raw value (e.g. `"programming"`).
    ///   - difficulty: Difficulty 1–5.
    ///   - skillContext: Optional user-supplied context string.
    ///   - count: Number of challenges to generate (default 3).
    /// - Returns: Unsaved ``Challenge`` objects ready to insert into SwiftData.
    func generateChallenges(
        skillName: String,
        category: String,
        difficulty: Int,
        skillContext: String,
        count: Int = 3
    ) async throws -> [Challenge] {
        // Detect language from skill title + context so questions match what the user typed.
        let langText = [skillName, skillContext].filter { !$0.isEmpty }.joined(separator: " ")
        let language = detectedLanguage(from: langText)
        let prompt = generationPrompt(
            skillName: skillName,
            category:  category,
            difficulty: difficulty,
            context:   skillContext,
            count: count,
            language: language
        )
        let raw  = try await sendPrompt(isGeneration: true, maxTokens: generationTokenBudget(for: count), prompt: prompt)
        let dtos = try parseChallengeDTOs(from: raw)
        return dtos.map { mapToChallenge($0) }
    }

    // MARK: - Answer Evaluation

    /// Evaluates whether `userAnswer` is correct for a challenge.
    ///
    /// Objective types (`.multipleChoice`, `.trueFalse`) are evaluated locally
    /// without an API call. Subjective types use the active AI provider.
    ///
    /// Build a ``ChallengeEvalContext`` on `@MainActor` from the ``Challenge`` model
    /// object before crossing into this actor.
    ///
    /// - Parameters:
    ///   - context: Sendable snapshot of the challenge being evaluated.
    ///   - userAnswer: The answer string supplied by the user.
    ///   - responseTime: How long the user took; used to infer confidence.
    func evaluateAnswer(
        context: ChallengeEvalContext,
        userAnswer: String,
        responseTime: TimeInterval = 0
    ) async throws -> EvaluationResult {
        // Fast-path: objective types evaluated locally
        if context.type == .multipleChoice || context.type == .trueFalse {
            let correct = userAnswer
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(
                    context.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                ) == .orderedSame
            let confidence = inferredConfidence(responseTime: responseTime,
                                                timeLimitSeconds: context.timeLimitSeconds,
                                                isCorrect: correct)
            let feedback = correct
                ? context.explanation
                : "Correct answer: \(context.correctAnswer). \(context.explanation)"
            return EvaluationResult(isCorrect: correct,
                                    feedback: feedback,
                                    inferredConfidence: confidence)
        }

        // Subjective types — ask AI provider
        let prompt = evaluationPrompt(context: context, userAnswer: userAnswer)
        let raw    = try await sendPrompt(isGeneration: false, maxTokens: 256, prompt: prompt)
        let dto    = try parseEvaluationDTO(from: raw)
        let confidence = parseConfidence(dto.confidenceHint,
                                          responseTime: responseTime,
                                          timeLimitSeconds: context.timeLimitSeconds,
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
        count: Int,
        language: String
    ) -> String {
        let contextLine = context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\nUser context: \(context.trimmingCharacters(in: .whitespacesAndNewlines))"
        return """
        You are an expert educator generating knowledge-testing challenges for a spaced-repetition learning app.
        Generate exactly \(count) challenges that TEST THE USER'S KNOWLEDGE of: "\(skillName)" (category: \(category)).\(contextLine)
        Target difficulty: \(difficulty)/5.
        IMPORTANT: Write all questions, options, and explanations in \(language). Do not use any other language.

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

    private func evaluationPrompt(context: ChallengeEvalContext, userAnswer: String) -> String {
        let contextLine = context.skillContext.isEmpty ? "" : "\nSkill context: \(context.skillContext)"
        let langText = [context.question, context.skillContext].filter { !$0.isEmpty }.joined(separator: " ")
        let language = detectedLanguage(from: langText)
        return """
        Evaluate whether the user's answer is correct for this challenge.\(contextLine)
        Write the feedback field in \(language).

        Challenge type: \(context.type.rawValue)
        Question: \(context.question)
        Correct answer: \(context.correctAnswer)
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
        let langText = [name, context].filter { !$0.isEmpty }.joined(separator: " ")
        let language = detectedLanguage(from: langText)
        let prompt = breadthPrompt(name: name, context: context, language: language)
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

    private func breadthPrompt(name: String, context: String = "", language: String) -> String {
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
        Write sub-skill names in \(language).

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

