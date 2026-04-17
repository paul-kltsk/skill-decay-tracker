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

    /// Number of AI breadth calls made during this creation flow.
    private(set) var focusCheckCount: Int = 0

    /// Hard cap on AI breadth calls per AddSkillViewModel instance.
    let focusCheckLimit = 10

    /// In-memory cache keyed by trimmed skill name. Stores result for each unique name
    /// so editing back to a previously-checked name costs zero tokens.
    private var focusCache: [String: [SkillSuggestion]] = [:]

    /// Running analysis task — kept so it can be cancelled when the name changes.
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

    /// Starts background generation of exactly 5 questions (the minimum baseline).
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

    /// Appends the questions needed to reach `selectedQuestionCount`.
    ///
    /// Cancels the baseline task first so its eventual assignment can't overwrite
    /// the top-up result.
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

    /// Clears current suggestions and cancels any in-flight analysis.
    func clearFocusSuggestions() {
        nameCheckTask?.cancel()
        nameCheckTask = nil
        focusSuggestions = []
        isAnalyzingFocus = false
    }

    /// Triggers a breadth analysis for the current skill name.
    ///
    /// Fires on blur (not per-keystroke). Results are cached by name; hard-capped at
    /// `focusCheckLimit` real AI calls per ViewModel instance.
    func analyzeNameIfNeeded() {
        nameCheckTask?.cancel()
        let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // Cache hit — free, no network call
        if let cached = focusCache[name] {
            focusSuggestions = cached
            return
        }

        // Hard limit reached — silently skip
        guard focusCheckCount < focusCheckLimit else { return }

        let ctx      = skillContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = selectedCategory

        nameCheckTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            isAnalyzingFocus = true
            focusCheckCount += 1
            let suggestions = await AIService.shared.analyzeSkillBreadth(
                name: name, context: ctx, category: category)
            guard !Task.isCancelled else {
                isAnalyzingFocus = false
                return
            }
            isAnalyzingFocus = false
            focusCache[name] = suggestions   // cache even empty results
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
        case 1: return String(localized: "Easy")
        case 2: return String(localized: "Moderate")
        case 3: return String(localized: "Average")
        case 4: return String(localized: "Challenging")
        default: return String(localized: "Hard")
        }
    }

    var difficultyDescription: String {
        switch Int(initialDifficulty.rounded()) {
        case 1: return String(localized: "Needs review every ~14 days")
        case 2: return String(localized: "Needs review every ~7 days")
        case 3: return String(localized: "Needs review every ~5 days")
        case 4: return String(localized: "Needs review every ~3 days")
        default: return String(localized: "Needs review every ~1 day")
        }
    }

    // MARK: - Navigation

    var canAdvance: Bool {
        switch currentStep {
        case 0: return isNameValid
        default: return true
        }
    }

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
