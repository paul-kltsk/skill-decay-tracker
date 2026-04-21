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
    let correctAnswer: String?   // nil for open_ended / fill_in_blank
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

    // MARK: - Prompt Constants & Helpers

    /// Identical to the system prompt injected by the proxy server (`sdt-proxy/src/providers.ts`).
    /// Injected into all own-key generation requests to guarantee JSON-only output, matching
    /// proxy behavior and eliminating markdown-wrapped responses.
    private let jsonOnlySystemPrompt =
        "You are a JSON-only API. You must respond with valid JSON only. " +
        "Do not include any markdown, code blocks, or explanatory text. " +
        "Return only the raw JSON object or array."

    /// Maps a skill's health score to a retention-aware instruction.
    /// Mirrors `retentionHint()` in `sdt-proxy/src/prompts.ts`.
    private func retentionHint(healthScore: Double) -> String {
        if healthScore >= 0.8 { return "test edge cases and advanced scenarios" }
        if healthScore >= 0.5 { return "reinforce core concepts" }
        return "focus on fundamentals and basic understanding"
    }

    /// Computes the exact question-type breakdown for `count` questions.
    /// Mirrors `typeDistribution()` in `sdt-proxy/src/prompts.ts`.
    private func typeDistribution(count: Int) -> String {
        switch count {
        case 1:  return "1 multiple_choice"
        case 2:  return "1 multiple_choice, 1 open_ended"
        case 3:  return "2 multiple_choice, 1 open_ended"
        default: return "\(count - 2) multiple_choice, 1 true_false, 1 open_ended"
        }
    }

    // MARK: - Language Detection

    /// Detects the dominant language of `text` using on-device NLP.
    ///
    /// Returns a human-readable label + BCP-47 code, e.g. `"Russian (ru)"`.
    /// Injected into AI prompts so generated content matches the skill's language,
    /// not the device locale.  Falls back to `"English (en)"` when detection fails
    /// (very short text, mixed script, etc.).
    private func detectedLanguage(from text: String) -> String {
        // Short text (e.g. "SwiftData", "Git") can't be reliably detected —
        // fall back to device language immediately.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 20 {
            return deviceLanguage()
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        // Require high confidence before trusting NLP result.
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        if let (lang, confidence) = hypotheses.first, confidence >= 0.7 {
            let code = lang.rawValue
            let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
            return "\(name) (\(code))"
        }

        return deviceLanguage()
    }

    /// Returns the user's preferred device language as a human-readable label + BCP-47 code.
    private func deviceLanguage() -> String {
        // Locale.preferredLanguages.first gives the top language from Settings → General → Language
        let bcp47 = Locale.preferredLanguages.first ?? "en"
        // Strip region suffix: "en-US" → "en", "ru-RU" → "ru", "pl-PL" → "pl"
        let code = String(bcp47.prefix(2))
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
    ///   - systemPrompt: Optional system-level instruction (empty string = omit).
    ///   - prompt: The full user-turn prompt.
    private func sendPrompt(isGeneration: Bool, maxTokens: Int, systemPrompt: String = "", prompt: String) async throws -> String {
        let provider = AIProvider.persisted

        if ProviderKeychain.has(for: provider) {
            // Own-key path: use the user-selected model tiers (generation and eval are independent).
            let tier = isGeneration ? AIModelTier.persisted : AIModelTier.persistedEval
            let model = tier.generationModelID(for: provider)
            switch provider {
            case .claude:
                return try await ClaudeAPIClient.shared.send(model: model,
                                                             maxTokens: maxTokens,
                                                             systemPrompt: systemPrompt,
                                                             prompt: prompt)
            case .openai:
                return try await OpenAIClient.shared.send(model: model,
                                                          maxTokens: maxTokens,
                                                          systemPrompt: systemPrompt,
                                                          prompt: prompt)
            case .gemini:
                return try await GeminiClient.shared.send(model: model,
                                                          maxTokens: maxTokens,
                                                          systemPrompt: systemPrompt,
                                                          prompt: prompt)
            }
        } else {
            // Proxy path: always use fast (cost-efficient) models — server bears the cost.
            let model = isGeneration
                ? AIModelTier.fast.generationModelID(for: provider)
                : AIModelTier.fast.generationModelID(for: provider)
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
        skillName:       String,
        category:        String,
        difficulty:      Int,
        skillContext:    String,
        healthScore:     Double = 0.5,
        recentQuestions: [String] = [],
        count:           Int = 3
    ) async throws -> [Challenge] {
        let langText = [skillName, skillContext].filter { !$0.isEmpty }.joined(separator: " ")
        let language = detectedLanguage(from: langText)
        let provider = AIProvider.persisted

        let raw: String
        if ProviderKeychain.has(for: provider) {
            let prompt = generationPrompt(
                skillName:       skillName,
                category:        category,
                difficulty:      difficulty,
                context:         skillContext,
                count:           count,
                language:        language,
                healthScore:     healthScore,
                recentQuestions: recentQuestions
            )
            raw = try await sendPrompt(isGeneration: true,
                                       maxTokens: generationTokenBudget(for: count),
                                       systemPrompt: jsonOnlySystemPrompt,
                                       prompt: prompt)
        } else {
            let model = AIModelTier.fast.generationModelID(for: provider)
            raw = try await ProxyAPIClient.shared.generate(
                provider:        provider,
                model:           model,
                skillName:       skillName,
                category:        category,
                difficulty:      difficulty,
                healthScore:     healthScore,
                language:        language,
                count:           count,
                context:         skillContext,
                recentQuestions: recentQuestions
            )
        }

        let dtos = try parseChallengeDTOs(from: raw)
        return Array(dtos.prefix(count)).map { mapToChallenge($0) }
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
        let provider = AIProvider.persisted
        let langText = [context.question, context.skillContext].filter { !$0.isEmpty }.joined(separator: " ")
        let language = detectedLanguage(from: langText)

        let raw: String
        if ProviderKeychain.has(for: provider) {
            let prompt = evaluationPrompt(context: context, userAnswer: userAnswer)
            raw = try await sendPrompt(isGeneration: false, maxTokens: 256, prompt: prompt)
        } else {
            let model = AIModelTier.fast.generationModelID(for: provider)
            raw = try await ProxyAPIClient.shared.evaluate(
                provider:      provider,
                model:         model,
                challengeType: context.type.rawValue,
                question:      context.question,
                correctAnswer: context.correctAnswer,
                explanation:   context.explanation,
                skillContext:  context.skillContext,
                userAnswer:    userAnswer,
                language:      language
            )
        }
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
        language: String,
        healthScore: Double,
        recentQuestions: [String]
    ) -> String {
        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextLine = trimmedContext.isEmpty
            ? ""
            : "\nFocus STRICTLY on the sub-topic \"\(trimmedContext)\" within \(skillName). Do NOT generate questions on unrelated topics."

        let avoidSection: String
        if recentQuestions.isEmpty {
            avoidSection = ""
        } else {
            let list = recentQuestions.prefix(10).map { "- \($0)" }.joined(separator: "\n")
            avoidSection = "\n\nDo NOT repeat or rephrase any of these questions:\n\(list)"
        }

        return """
        Generate exactly \(count) challenges that TEST THE USER'S KNOWLEDGE of: "\(skillName)" (category: \(category)).\(contextLine)
        Target difficulty: \(difficulty)/5.
        Retention goal: \(retentionHint(healthScore: healthScore)).
        IMPORTANT: Write all questions, options, and explanations in \(language). Do not use any other language.

        Rules:
        - Questions must test FACTUAL KNOWLEDGE, comprehension, or application of the topic — not self-awareness or self-rating.
        - FORBIDDEN question types: "How would you rate your understanding?", "Can you explain X?" as True/False, any self-assessment. These are strictly prohibited.
        - For multiple_choice: write a concrete factual question with exactly 4 plausible but distinct options; only one is correct.
        - For true_false: state a specific factual claim about the topic that is clearly true or false (e.g. "ARC increments an object's retain count when a strong reference is created"). Options must be ["True", "False"].
        - For open_ended or fill_in_blank: ask the user to explain a mechanism, predict output, or fill in a missing term/keyword.
        - Type distribution: generate exactly \(typeDistribution(count: count)).
        - Each challenge must take 1–3 minutes to answer.
        - The explanation must be educational — explain WHY the answer is correct, not just state it.
        - difficulty must be an integer 1–5.\(avoidSection)

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
        let provider = AIProvider.persisted

        let raw: String
        do {
            if ProviderKeychain.has(for: provider) {
                let prompt = breadthPrompt(name: name, context: context, language: language)
                raw = try await sendPrompt(isGeneration: false, maxTokens: 256, prompt: prompt)
            } else {
                let model = AIModelTier.fast.generationModelID(for: provider)
                raw = try await ProxyAPIClient.shared.analyzeBreadth(
                    provider:  provider,
                    model:     model,
                    skillName: name,
                    context:   context,
                    category:  category.rawValue,
                    language:  language
                )
            }
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

        Decide if this topic is TOO BROAD to practice effectively without a concrete focus goal.

        TOO BROAD — suggest 3-4 focused practice goals (short, actionable phrases):
        - Entire programming languages: "Swift", "Python", "JavaScript", "Kotlin", "Go"
        - Entire human languages: "Spanish", "Japanese", "French"
        - Vast domains: "Machine Learning", "iOS Development", "Web Development", "Design"

        SPECIFIC ENOUGH — return empty subSkills:
        - A named feature or concept: "Swift ARC", "React Hooks", "Git Rebase", "Spanish Grammar"
        - A concrete goal already mentioned in context
        - Anything the user can realistically practice in focused sessions as-is

        If the user provided a goal/context, the topic is already specific enough — return empty subSkills.

        Write focus goal names in \(language). Keep each suggestion short (2–5 words) and goal-oriented,
        e.g. "Memory management & ARC", "B2 grammar & writing", "REST API design".

        Respond ONLY with valid JSON, no markdown:
        {"subSkills": [{"name": "Memory management & ARC", "category": "programming"}]}

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

    /// Extracts the first valid JSON array or object from `text`.
    ///
    /// Handles markdown code-fence wrappers (` ```json ... ``` `) that Claude
    /// sometimes emits despite the "JSON-only" system prompt.
    private func extractJSON(from text: String) -> String {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fast path: already clean JSON
        if s.hasPrefix("[") || s.hasPrefix("{") { return s }

        // Find the first JSON boundary character and match closing bracket
        let arrayStart  = s.firstIndex(of: "[")
        let objectStart = s.firstIndex(of: "{")

        let start: String.Index
        let close: Character

        switch (arrayStart, objectStart) {
        case (.some(let a), .some(let o)):
            if a < o { start = a; close = "]" }
            else      { start = o; close = "}" }
        case (.some(let a), nil): start = a; close = "]"
        case (nil, .some(let o)): start = o; close = "}"
        case (nil, nil):          return s   // no JSON found — return as-is
        }

        // Walk backwards from the end to find the last matching closing bracket
        guard let end = s.lastIndex(of: close) else { return s }
        guard start <= end else { return s }

        return String(s[start...end])
    }

    // MARK: - DTO → Model Mapping

    private func mapToChallenge(_ dto: ChallengeDTO) -> Challenge {
        Challenge(
            type:             ChallengeType(rawValue: dto.type) ?? .multipleChoice,
            question:         dto.question,
            options:          (dto.options ?? []).shuffled(),
            correctAnswer:    dto.correctAnswer ?? "",
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

