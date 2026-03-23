import SwiftUI
import SwiftData

// MARK: - Session Mode

/// The three practice modes available from ``SessionLauncherView``.
enum SessionMode: Sendable {
    /// All overdue skills — up to 2 challenges each, sorted by urgency.
    case dailyReview
    /// The single most-critical skill — up to 5 challenges.
    case quickPractice
    /// One user-selected skill — all available challenges.
    case deepDive(skillID: UUID)

    var analyticsName: String {
        switch self {
        case .dailyReview:   "daily_review"
        case .quickPractice: "quick_practice"
        case .deepDive:      "deep_dive"
        }
    }
}

// MARK: - Practice Phase

/// State machine phases for the practice session.
enum PracticePhase: Equatable {
    case idle
    case loading
    case inChallenge
    case evaluating
    case showingFeedback
    case sessionComplete
    case error(String)
    /// The proxy server returned HTTP 429 — daily request limit exhausted.
    /// `retryAfter` is the number of seconds until the limit resets.
    case rateLimited(retryAfter: TimeInterval)
}

// MARK: - Difficulty Adjustment Suggestion

/// A suggestion to raise or lower the difficulty of a specific skill,
/// generated automatically when the user's session performance is consistently
/// too easy (≥90% accuracy) or too hard (≤35% accuracy).
struct DifficultyAdjustment: Sendable, Identifiable {
    enum Direction: Sendable {
        case increase   // user is acing it — make it harder
        case decrease   // user is struggling — make it easier
    }

    let id = UUID()
    let skillID: UUID
    let skillName: String
    let direction: Direction
    /// Accuracy achieved in this session for this specific skill (0…1).
    let sessionAccuracy: Double
    /// Number of challenges answered for this skill in the session.
    let challengeCount: Int
}

// MARK: - Session Summary

/// Immutable summary produced at the end of a session.
struct SessionSummary: Sendable {
    let totalChallenges: Int
    let correctCount: Int
    let xpEarned: Int
    let skillNames: [String]
    let durationSeconds: Int
    /// Difficulty-adjustment suggestions — one per skill where performance was notably one-sided.
    let adjustments: [DifficultyAdjustment]

    var accuracy: Double {
        guard totalChallenges > 0 else { return 0 }
        return Double(correctCount) / Double(totalChallenges)
    }
}

// MARK: - Practice ViewModel

/// Drives the full practice session lifecycle.
///
/// **State machine:** `idle → loading → inChallenge ⇄ evaluating → showingFeedback → (loop or sessionComplete)`
///
/// Consumers observe `phase` to decide which UI to show.
/// ``ChallengeView`` owns the ViewModel as `@State` and passes it down as `@Bindable`.
@Observable
@MainActor
final class PracticeViewModel {

    // MARK: - Public State

    var phase: PracticePhase = .idle
    /// Set to `true` when a session starts; drives `.fullScreenCover` in launcher.
    var isSessionActive = false

    /// Challenges queued for this session (shuffled).
    private(set) var challenges: [Challenge] = []
    /// Index of the currently displayed challenge.
    private(set) var currentIndex = 0

    /// The text answer typed by the user (open-ended / code types).
    var userAnswer = ""
    /// The option tapped by the user (multiple-choice / true-false types).
    var selectedOption: String? = nil

    /// The evaluation result for the challenge just answered.
    private(set) var evaluationResult: EvaluationResult? = nil

    /// Seconds remaining on the current challenge's countdown.
    private(set) var timeRemaining = 0

    /// Summary available once `phase == .sessionComplete`.
    private(set) var summary: SessionSummary? = nil

    // MARK: - Private State

    private var sessionResults: [ChallengeResult] = []
    private var sessionXP = 0
    private var sessionStartTime = Date.now
    private var answerStartTime  = Date.now
    private var reviewedSkillNames: Set<String> = []
    private var timerTask: Task<Void, Never>? = nil
    private var currentMode: SessionMode = .dailyReview
    /// Skills used in the last session — stored so the session can be retried on error.
    private var lastSessionSkills: [Skill] = []

    /// Per-skill accuracy tracker for this session.
    /// Key = skill UUID, value = (skillName, correctCount, totalCount).
    private var sessionSkillStats: [UUID: (name: String, correct: Int, total: Int)] = [:]

    /// Number of challenges to generate per session, from the user's preferred session length.
    /// Reads "preferredSessionLength" from UserDefaults (set in PracticePreferencesView).
    /// Minimum is always 5 so the user always gets a meaningful session.
    private var preferredSessionCount: Int {
        let raw = UserDefaults.standard.string(forKey: "preferredSessionLength") ?? "medium"
        let count = SessionLength(rawValue: raw)?.count ?? 10
        return max(5, count)
    }

    // MARK: - Computed

    var currentChallenge: Challenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    /// Session completion progress 0…1 (advances after each answer).
    var sessionProgress: Double {
        guard !challenges.isEmpty else { return 0 }
        return Double(currentIndex) / Double(challenges.count)
    }

    /// Timer fill 0…1 (1 = full time, 0 = expired).
    var timerProgress: Double {
        guard let c = currentChallenge, c.timeLimitSeconds > 0 else { return 1 }
        return Double(timeRemaining) / Double(c.timeLimitSeconds)
    }

    // MARK: - Lifecycle

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Start Session

    /// Retries the last session with the same mode and skills (used from error screen).
    func retrySession(context: ModelContext) async {
        await startSession(mode: currentMode, skills: lastSessionSkills, context: context)
    }

    /// Builds the challenge queue for `mode` and transitions to `.inChallenge`.
    /// - Parameter challengeCount: Override the preferred session length (e.g. from skill creation flow).
    func startSession(mode: SessionMode, skills: [Skill], context: ModelContext, challengeCount: Int? = nil) async {
        currentMode        = mode
        lastSessionSkills  = skills
        phase              = .loading
        isSessionActive    = true
        sessionStartTime = Date.now
        sessionResults   = []
        sessionXP        = 0
        reviewedSkillNames = []

        var queue: [Challenge] = []

        switch mode {

        case .dailyReview:
            let overdue = skills
                .filter { $0.nextReviewDate <= Date.now }
                .sorted { $0.healthScore < $1.healthScore }
            for skill in overdue {
                let pending = skill.pendingChallenges
                if pending.isEmpty {
                    let new = await fetchOrGenerate(skill: skill, count: 3, context: context)
                    if case .rateLimited = phase { return }
                    queue.append(contentsOf: new.prefix(2))
                } else {
                    queue.append(contentsOf: pending.prefix(2))
                }
            }

        case .quickPractice:
            guard let skill = skills.min(by: { $0.healthScore < $1.healthScore }) else {
                phase = .error("No skills to practice. Add some skills first.")
                return
            }
            let target = challengeCount ?? preferredSessionCount
            var pending = skill.pendingChallenges
            // Only generate if we have fewer than 5 challenges (the pre-fetch minimum).
            // This ensures pre-fetched challenges from skill creation are used directly
            // without triggering a second AI round-trip.
            if pending.count < min(5, target) {
                let more = await fetchOrGenerate(
                    skill: skill, count: target - pending.count, context: context)
                if case .rateLimited = phase { return }
                pending.append(contentsOf: more)
            }
            queue = Array(pending.prefix(target))

        case .deepDive(let skillID):
            guard let skill = skills.first(where: { $0.id == skillID }) else {
                phase = .error("Skill not found.")
                return
            }
            let target = preferredSessionCount
            var pending = skill.pendingChallenges
            // Only generate if we have fewer than 5 challenges (the pre-fetch minimum).
            if pending.count < min(5, target) {
                let more = await fetchOrGenerate(
                    skill: skill, count: target - pending.count, context: context)
                if case .rateLimited = phase { return }
                pending.append(contentsOf: more)
            }
            queue = Array(pending.prefix(target))
        }

        try? context.save()
        challenges = queue.shuffled()
        currentIndex = 0

        if challenges.isEmpty {
            phase = .error("No challenges found. Try again or add more skills.")
        } else {
            AnalyticsService.sessionStarted(mode: mode.analyticsName, challengeCount: challenges.count)
            beginChallenge()
        }
    }

    // MARK: - Challenge Flow

    private func beginChallenge() {
        guard currentIndex < challenges.count else {
            finishSession()
            return
        }
        userAnswer    = ""
        selectedOption = nil
        evaluationResult = nil
        answerStartTime  = Date.now
        phase = .inChallenge
        startCountdown()

        if let skill = challenges[currentIndex].skill {
            reviewedSkillNames.insert(skill.name)
        }
    }

    /// Selects a tappable option (multiple-choice / true-false).
    func selectOption(_ option: String) {
        selectedOption = option
        userAnswer     = option
    }

    /// Submits the current answer, evaluates via AI, and updates the skill.
    func submitAnswer(context: ModelContext) async {
        guard let challenge = currentChallenge else { return }
        let answer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty || selectedOption != nil else { return }

        phase = .evaluating
        timerTask?.cancel()
        let elapsed = Date.now.timeIntervalSince(answerStartTime)

        do {
            let eval = try await AIService.shared.evaluateAnswer(
                challenge: challenge,
                userAnswer: answer,
                responseTime: elapsed
            )
            await recordResult(eval: eval, answer: answer,
                                elapsed: elapsed, challenge: challenge, context: context)
        } catch {
            // Evaluation failed — mark wrong, show fallback feedback
            let fallback = EvaluationResult(
                isCorrect: false,
                feedback: "Could not evaluate. Correct answer: \(challenge.correctAnswer). \(challenge.explanation)",
                inferredConfidence: .low
            )
            await recordResult(eval: fallback, answer: answer,
                                elapsed: elapsed, challenge: challenge, context: context)
        }
    }

    /// Skips the current challenge (counts as incorrect for decay purposes).
    func skipChallenge(context: ModelContext) {
        timerTask?.cancel()
        AnalyticsService.challengeSkipped(mode: currentMode.analyticsName)
        // Don't record — just move on without updating decay
        currentIndex += 1
        beginChallenge()
    }

    /// Advances to the next challenge after the feedback screen.
    func nextChallenge() {
        currentIndex += 1
        beginChallenge()
    }

    // MARK: - Timer

    private func startCountdown() {
        guard let c = currentChallenge, c.timeLimitSeconds > 0 else {
            timeRemaining = 0
            return
        }
        timeRemaining = c.timeLimitSeconds
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while timeRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
                if timeRemaining == 0 {
                    handleTimeExpired()
                }
            }
        }
    }

    private func handleTimeExpired() {
        guard phase == .inChallenge, let challenge = currentChallenge else { return }
        let fallback = EvaluationResult(
            isCorrect: false,
            feedback: "Time's up! Correct answer: \(challenge.correctAnswer). \(challenge.explanation)",
            inferredConfidence: .low
        )
        evaluationResult = fallback
        phase = .showingFeedback
    }

    // MARK: - Result Recording

    private func recordResult(
        eval: EvaluationResult,
        answer: String,
        elapsed: TimeInterval,
        challenge: Challenge,
        context: ModelContext
    ) async {
        let result = ChallengeResult(
            isCorrect: eval.isCorrect,
            responseTime: elapsed,
            confidenceRating: eval.inferredConfidence,
            userAnswer: answer,
            sessionPosition: currentIndex
        )
        context.insert(result)
        result.challenge = challenge
        challenge.results.append(result)
        challenge.isUsed = true

        // Schedule spaced-repetition review for weak answers.
        //
        // Wrong answer          → review in 1 day
        // Correct but not sure  → review in 2 days (fragile memory)
        // Correct + confident   → mastered, no review (nextReviewDate = nil)
        let cal = Calendar.current
        if !eval.isCorrect {
            challenge.nextReviewDate = cal.date(byAdding: .day, value: 1, to: Date.now)
        } else if eval.inferredConfidence == .low {
            challenge.nextReviewDate = cal.date(byAdding: .day, value: 2, to: Date.now)
        } else {
            challenge.nextReviewDate = nil   // mastered
        }

        if let skill = challenge.skill {
            // Track per-skill session accuracy for difficulty-adjustment suggestions.
            let sid = skill.id
            var stats = sessionSkillStats[sid] ?? (name: skill.name, correct: 0, total: 0)
            stats.total  += 1
            if eval.isCorrect { stats.correct += 1 }
            sessionSkillStats[sid] = stats

            DecayEngine.apply(result: result, to: skill)
            let xp = DecayEngine.xpReward(
                isCorrect: eval.isCorrect,
                difficulty: challenge.difficulty,
                confidence: eval.inferredConfidence
            )
            sessionXP += xp
            await applyXP(xp, context: context)
        }

        sessionResults.append(result)
        evaluationResult = eval
        phase = .showingFeedback
        try? context.save()
    }

    // MARK: - Session End

    private func finishSession() {
        timerTask?.cancel()
        let correct = sessionResults.filter { $0.isCorrect }.count

        // Build difficulty-adjustment suggestions.
        // Thresholds: ≥3 challenges per skill in this session to avoid noise.
        // Increase: accuracy ≥ 90% → questions are too easy.
        // Decrease: accuracy ≤ 35% → questions are too hard.
        let adjustments: [DifficultyAdjustment] = sessionSkillStats.compactMap { id, stats in
            guard stats.total >= 3 else { return nil }
            let acc = Double(stats.correct) / Double(stats.total)
            if acc >= 0.90 {
                return DifficultyAdjustment(skillID: id, skillName: stats.name,
                                            direction: .increase, sessionAccuracy: acc,
                                            challengeCount: stats.total)
            } else if acc <= 0.35 {
                return DifficultyAdjustment(skillID: id, skillName: stats.name,
                                            direction: .decrease, sessionAccuracy: acc,
                                            challengeCount: stats.total)
            }
            return nil
        }

        let duration = Int(Date.now.timeIntervalSince(sessionStartTime))
        let accuracyPct = sessionResults.isEmpty ? 0 : Int(Double(correct) / Double(sessionResults.count) * 100)
        AnalyticsService.sessionCompleted(
            mode: currentMode.analyticsName,
            accuracyPct: accuracyPct,
            durationSeconds: duration,
            xpEarned: sessionXP,
            skillCount: reviewedSkillNames.count
        )

        summary = SessionSummary(
            totalChallenges: sessionResults.count,
            correctCount: correct,
            xpEarned: sessionXP,
            skillNames: Array(reviewedSkillNames),
            durationSeconds: duration,
            adjustments: adjustments.sorted { $0.skillName < $1.skillName }
        )
        phase = .sessionComplete
    }

    /// Resets all state and dismisses the session cover.
    func endSession() {
        timerTask?.cancel()
        // Track abandonment: session was active, not yet complete, and at least one challenge was seen
        if isSessionActive && phase != .sessionComplete && !sessionResults.isEmpty {
            AnalyticsService.sessionAbandoned(
                mode: currentMode.analyticsName,
                completedChallenges: sessionResults.count,
                totalChallenges: challenges.count
            )
        }
        isSessionActive   = false
        phase             = .idle
        challenges        = []
        currentIndex      = 0
        summary           = nil
        sessionResults    = []
        sessionXP         = 0
        sessionSkillStats = [:]
    }

    // MARK: - Difficulty Adjustment

    /// Applies the user-accepted difficulty change to the matching skill.
    ///
    /// Looks up the skill from the session's challenge list by ID so we don't
    /// need to pass a separate `[Skill]` array from the view.
    func applyAdjustment(_ adjustment: DifficultyAdjustment, context: ModelContext) {
        guard let skill = challenges.first(where: { $0.skill?.id == adjustment.skillID })?.skill
        else { return }
        switch adjustment.direction {
        case .increase:
            DecayEngine.applyDifficultyIncrease(to: skill)
            AnalyticsService.difficultyAdjusted(direction: "increase")
        case .decrease:
            DecayEngine.applyDifficultyDecrease(to: skill)
            AnalyticsService.difficultyAdjusted(direction: "decrease")
        }
        try? context.save()
    }

    // MARK: - Helpers

    /// Generates new challenges for `skill` via AIService and inserts them into the context.
    private func fetchOrGenerate(skill: Skill, count: Int, context: ModelContext) async -> [Challenge] {
        do {
            let new = try await AIService.shared.generateChallenges(for: skill, count: count)
            for c in new {
                skill.challenges.append(c)
                context.insert(c)
            }
            return new
        } catch let apiError as APIError {
            if case .rateLimited(let retryAfter) = apiError {
                // Propagate rate-limit directly — caller should abort and show the rate-limit screen.
                phase = .rateLimited(retryAfter: retryAfter)
            }
            // All other API errors (network, bad JSON, etc.) fall through silently.
            return []
        } catch {
            return []
        }
    }

    private func applyXP(_ xp: Int, context: ModelContext) async {
        guard xp > 0 else { return }
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? context.fetch(descriptor))?.first else { return }
        profile.xp += xp
        while profile.xp >= profile.xpToNextLevel {
            profile.level += 1
        }
    }
}
