import SwiftUI
import SwiftData

/// ViewModel for the 5-step ``AddSkillView`` sheet.
///
/// **Step flow:** Name → Category → Difficulty → Question Count → Confirm
///
/// As the user types on step 0, a debounced AI breadth analysis fires automatically
/// and may populate `focusSuggestions` — pre-filled "Focus / goal" options the user
/// can tap to speed up entry. Selecting one writes directly into `skillContext` without
/// changing the rest of the flow.
@Observable
@MainActor
final class AddSkillViewModel {

    // MARK: - Step State

    /// The currently visible step (0-indexed).
    var currentStep: Int = 0

    // MARK: - Step 1: Name

    var skillName: String = ""
    var nameError: String? = nil

    var isNameValid: Bool {
        !skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Step 1b: Context / Focus

    /// Free-text goal or context the user provides — injected verbatim into AI prompts.
    var skillContext: String = ""

    // MARK: - Step 3.5: Question Count

    /// Number of questions to generate per practice session. Default 5 (free tier max).
    /// Pro users can pick 5–15.
    var selectedQuestionCount: Int = 5

    // MARK: - Focus Analysis (breadth check)

    /// AI-generated focus-goal suggestions — populated when AI detects the topic is broad.
    /// Internal (not private) so unit tests can inject values without hitting the network.
    var focusSuggestions: [SkillSuggestion] = []

    /// `true` while the background breadth analysis is in flight.
    private(set) var isAnalyzingFocus = false

    /// Debounce task for the name-change–triggered breadth analysis.
    private var nameCheckTask: Task<Void, Never>?

    // MARK: - Challenge Pre-Generation

    /// AI-generated challenges for the skill — ready before the user taps "Start Practice".
    ///
    /// Built in two phases:
    /// 1. **Baseline** — 5 questions generated as soon as the user lands on step 3.
    /// 2. **Top-up** — the delta (`selectedQuestionCount - 5`) appended when they advance to step 4.
    var prefetchedChallenges: [Challenge] = []

    /// True while challenges are being pre-generated in the background.
    private(set) var isPrefetchingChallenges = false

    /// Tracks the running baseline task so top-up can cancel it if the user advances early.
    private var baselineTask: Task<Void, Never>?

    /// Shared AI prompt parameters.
    private var prefetchPromptParams: (name: String, category: SkillCategory, ctx: String, difficulty: Int) {
        let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ctx  = skillContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let tempSkill = Skill(name: name, category: selectedCategory, context: ctx, decayRate: difficultyDecayRate)
        return (name, selectedCategory, ctx, tempSkill.effectiveDifficulty)
    }

    /// Phase 1 — starts a background task that generates exactly 5 questions (the minimum).
    ///
    /// Called when the user lands on the Question Count step (step 3). Synchronous so the
    /// SwiftUI `.task` modifier fires it without awaiting — the real work happens inside
    /// `baselineTask`.
    func startBaselinePrefetch() {
        baselineTask?.cancel()
        baselineTask = nil
        isPrefetchingChallenges = true
        prefetchedChallenges = []

        let p = prefetchPromptParams
        baselineTask = Task {
            guard !Task.isCancelled else { return }
            if let generated = try? await AIService.shared.generateChallenges(
                skillName: p.name,
                category: p.category.rawValue,
                difficulty: p.difficulty,
                skillContext: p.ctx,
                count: 5
            ) {
                guard !Task.isCancelled else { return }
                self.prefetchedChallenges = generated
                self.isPrefetchingChallenges = false
            } else {
                self.isPrefetchingChallenges = false
            }
        }
    }

    /// Phase 2 — appends the questions needed to reach `selectedQuestionCount`.
    ///
    /// Called from `advance()` when leaving step 3. Cancels the baseline task first so
    /// its eventual assignment can't overwrite the top-up result.
    func startTopUpPrefetch() async {
        baselineTask?.cancel()
        baselineTask = nil

        let current = prefetchedChallenges
        let needed  = selectedQuestionCount - current.count

        guard needed > 0 else {
            prefetchedChallenges = Array(current.prefix(selectedQuestionCount))
            return
        }

        isPrefetchingChallenges = true
        defer { isPrefetchingChallenges = false }

        let recentQ = current.map { $0.question }
        let p = prefetchPromptParams

        if let extra = try? await AIService.shared.generateChallenges(
            skillName: p.name,
            category: p.category.rawValue,
            difficulty: p.difficulty,
            skillContext: p.ctx,
            recentQuestions: recentQ,
            count: needed
        ) {
            guard !Task.isCancelled else { return }
            prefetchedChallenges = current + extra
        }
    }

    // MARK: - Focus Analysis

    /// Debounced breadth analysis triggered whenever the user changes the skill name.
    ///
    /// Waits 700 ms after the last keystroke, then calls the AI. Populates
    /// `focusSuggestions` with 0–4 focus-goal options; empty = topic is specific enough.
    func scheduleNameAnalysis() {
        nameCheckTask?.cancel()
        focusSuggestions = []
        let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            isAnalyzingFocus = false
            return
        }
        let ctx = skillContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = selectedCategory
        nameCheckTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            isAnalyzingFocus = true
            let suggestions = await AIService.shared.analyzeSkillBreadth(
                name: name, context: ctx, category: category)
            guard !Task.isCancelled else {
                isAnalyzingFocus = false
                return
            }
            isAnalyzingFocus = false
            focusSuggestions = suggestions
        }
    }

    // MARK: - Step 2: Category

    var selectedCategory: SkillCategory = .programming

    // MARK: - Step 3: Difficulty

    /// Perceived learning difficulty: 1 (easy) → 5 (hard).
    var initialDifficulty: Double = 3

    var difficultyDecayRate: Double {
        let t = (initialDifficulty - 1) / 4
        return 0.05 + t * 0.13
    }

    var difficultyLabel: String {
        switch Int(initialDifficulty.rounded()) {
        case 1: return "Easy"
        case 2: return "Moderate"
        case 3: return "Average"
        case 4: return "Challenging"
        default: return "Hard"
        }
    }

    var difficultyDescription: String {
        switch Int(initialDifficulty.rounded()) {
        case 1: return "Needs review every ~14 days"
        case 2: return "Needs review every ~7 days"
        case 3: return "Needs review every ~5 days"
        case 4: return "Needs review every ~3 days"
        default: return "Needs review every ~1 day"
        }
    }

    // MARK: - Navigation

    var canAdvance: Bool {
        switch currentStep {
        case 0: return isNameValid
        default: return true
        }
    }

    /// Advances to the next step. Advancing from step 3 kicks off the top-up prefetch.
    func advance() {
        guard canAdvance else { return }
        nameCheckTask?.cancel()     // no need to keep analysing once user proceeds
        isAnalyzingFocus = false
        let leavingCountStep = currentStep == 3
        nameError = nil
        let next = currentStep + 1
        guard next <= 4 else { return }
        currentStep = next
        if leavingCountStep {
            Task { await startTopUpPrefetch() }
        }
    }

    func back() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    // MARK: - Save

    /// Creates the skill and attaches any pre-generated challenges.
    ///
    /// - Returns: The inserted `Skill` object so callers can trigger additional work.
    @discardableResult
    func saveAll(context: ModelContext) -> [Skill] {
        let contextText = skillContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let rate = difficultyDecayRate
        let difficulty = Int(initialDifficulty.rounded())

        let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let skill = Skill(name: name, category: selectedCategory,
                          context: contextText, decayRate: rate)
        skill.questionCount = selectedQuestionCount
        context.insert(skill)
        if !prefetchedChallenges.isEmpty {
            prefetchedChallenges.forEach { c in
                skill.challenges = (skill.challenges ?? []) + [c]
                context.insert(c)
            }
        }
        do { try context.save() } catch {
            #if DEBUG
            print("[\(Self.self)] context.save() failed: \(error)")
            #endif
        }
        WidgetDataService.refresh(context: context)
        AnalyticsService.skillAdded(
            category: selectedCategory.rawValue,
            isSplit: false,
            subskillCount: 0,
            difficulty: difficulty
        )
        return [skill]
    }

    // MARK: - Quick-fill from Suggestion

    /// Fills the name and category from a tapped curated suggestion.
    func apply(suggestion: SkillSuggestion) {
        skillName        = suggestion.name
        selectedCategory = suggestion.category
    }
}
