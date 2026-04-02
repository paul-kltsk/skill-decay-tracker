import SwiftUI
import SwiftData

/// ViewModel for the 4-step ``AddSkillView`` sheet.
///
/// **Step flow (normal):** Name → Category → Difficulty → Confirm
/// **Step flow (splitting):** Name → Difficulty → Confirm  (category step skipped;
///   AI assigns per-sub-skill categories)
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

    // MARK: - Step 1b: Context

    /// Free-text goal or context the user provides — injected verbatim into AI prompts.
    var skillContext: String = ""

    // MARK: - Step 3.5: Question Count

    /// Number of questions to generate per practice session. Default 5 (free tier max).
    /// Pro users can pick 5–15.
    var selectedQuestionCount: Int = 5

    // MARK: - Sub-Skill Analysis

    /// AI-generated sub-skill suggestions — populated when AI says the topic is too broad.
    /// Internal (not private) so unit tests can inject values without hitting the network.
    var subSkillSuggestions: [SkillSuggestion] = []
    /// IDs of suggestions the user has selected to split into.
    var selectedSubSkillIDs: Set<UUID> = []
    /// True while the "Check & Continue" AI request is in flight.
    private(set) var isCheckingAndAdvancing = false

    // MARK: - Challenge Pre-Generation

    /// AI-generated challenges for the first skill — ready before the user taps "Start Practice".
    ///
    /// Populated when the user arrives at the Confirm step so the session can
    /// start instantly without a loading screen.
    var prefetchedChallenges: [Challenge] = []

    /// True while challenges are being pre-generated in the background.
    private(set) var isPrefetchingChallenges = false

    /// Pre-generates AI challenges using the current skill settings.
    ///
    /// Called when the user reaches the Confirm step (step 3).
    /// Creates a temporary, un-persisted `Skill` object to drive the AI prompt,
    /// then stores the resulting challenges so `saveAll` can link them instantly.
    func prefetchChallengesForCurrentSettings() async {
        isPrefetchingChallenges = true
        prefetchedChallenges    = []
        defer { isPrefetchingChallenges = false }

        guard !Task.isCancelled else { return }

        // Build a temporary skill for the AI prompt (not inserted into context).
        let firstName = isSplitting
            ? (selectedSubSkills.first?.name ?? skillName.trimmingCharacters(in: .whitespacesAndNewlines))
            : skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstCategory = isSplitting
            ? (selectedSubSkills.first?.category ?? selectedCategory)
            : selectedCategory
        let ctx      = skillContext.trimmingCharacters(in: .whitespacesAndNewlines)
        // Create a temporary skill only to compute effectiveDifficulty, then extract scalars
        // so no @Model object crosses the actor boundary into AIService.
        let tempSkill  = Skill(name: firstName, category: firstCategory,
                               context: ctx, decayRate: difficultyDecayRate)
        let difficulty = tempSkill.effectiveDifficulty

        if let generated = try? await AIService.shared.generateChallenges(
            skillName: firstName,
            category: firstCategory.rawValue,
            difficulty: difficulty,
            skillContext: ctx,
            count: selectedQuestionCount
        ) {
            guard !Task.isCancelled else { return }
            prefetchedChallenges = generated
        }
    }

    /// Called when the user taps "Check & Continue" on step 0.
    ///
    /// - If the skill name is specific enough → advances to next step automatically.
    /// - If the topic is broad → stays on step 0 and shows split suggestions.
    func checkThenAdvance() async {
        guard isNameValid else {
            nameError = "Please enter a skill name."
            return
        }
        nameError = nil
        let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ctx  = skillContext.trimmingCharacters(in: .whitespacesAndNewlines)

        isCheckingAndAdvancing = true
        subSkillSuggestions    = []
        selectedSubSkillIDs    = []

        let suggestions = await AIService.shared.analyzeSkillBreadth(
            name: name, context: ctx, category: selectedCategory)

        isCheckingAndAdvancing = false

        if suggestions.isEmpty {
            // Specific enough — advance straight to the next step.
            currentStep = nextStep(after: 0)
        } else {
            // Broad topic — show split options; user taps Continue when ready.
            subSkillSuggestions = suggestions
        }
    }

    /// Toggles selection of a sub-skill suggestion chip.
    func toggleSubSkill(_ suggestion: SkillSuggestion) {
        if selectedSubSkillIDs.contains(suggestion.id) {
            selectedSubSkillIDs.remove(suggestion.id)
        } else {
            selectedSubSkillIDs.insert(suggestion.id)
        }
    }

    /// The suggestions the user has opted in to.
    var selectedSubSkills: [SkillSuggestion] {
        subSkillSuggestions.filter { selectedSubSkillIDs.contains($0.id) }
    }

    /// True when the user has selected at least one sub-skill to split into.
    var isSplitting: Bool { !selectedSubSkills.isEmpty }

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

    /// Advances the step without running AI checks.
    /// Use ``checkThenAdvance()`` for step 0; this is for steps 1–3.
    func advance() {
        guard canAdvance else { return }
        nameError = nil
        let next = nextStep(after: currentStep)
        guard next <= 4 else { return }
        currentStep = next
    }

    func back() {
        guard currentStep > 0 else { return }
        currentStep = prevStep(before: currentStep)
    }

    /// When splitting, category step (1) is skipped.
    private func nextStep(after step: Int) -> Int {
        if step == 0 && isSplitting { return 2 }
        return step + 1
    }

    private func prevStep(before step: Int) -> Int {
        if step == 2 && isSplitting { return 0 }
        return step - 1
    }

    // MARK: - Save

    /// Creates one skill per selected sub-skill, or the original skill when not splitting.
    ///
    /// - Returns: All inserted `Skill` objects so callers can trigger AI pre-fetch.
    @discardableResult
    func saveAll(context: ModelContext) -> [Skill] {
        let contextText = skillContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let rate = difficultyDecayRate
        let difficulty = Int(initialDifficulty.rounded())
        if isSplitting {
            let skills = selectedSubSkills.map { sub in
                Skill(name: sub.name, category: sub.category,
                      context: contextText, decayRate: rate)
            }
            skills.forEach { context.insert($0) }
            // Link any pre-generated challenges to the first sub-skill so its
            // practice session can start without an extra AI round-trip.
            if let firstSkill = skills.first, !prefetchedChallenges.isEmpty {
                prefetchedChallenges.forEach { c in
                    firstSkill.challenges = (firstSkill.challenges ?? []) + [c]
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
                category: selectedSubSkills.first?.category.rawValue ?? selectedCategory.rawValue,
                isSplit: true,
                subskillCount: skills.count,
                difficulty: difficulty
            )
            return skills
        } else {
            let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
            let skill = Skill(name: name, category: selectedCategory,
                              context: contextText, decayRate: rate)
            context.insert(skill)
            // Link any pre-generated challenges so practice starts instantly.
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
    }

    // MARK: - Quick-fill from Suggestion

    /// Fills the name and category from a tapped curated suggestion.
    func apply(suggestion: SkillSuggestion) {
        skillName        = suggestion.name
        selectedCategory = suggestion.category
    }
}
