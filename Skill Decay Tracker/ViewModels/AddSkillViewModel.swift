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

    // MARK: - Sub-Skill Analysis

    /// AI-generated sub-skill suggestions (populated after name debounce).
    private(set) var subSkillSuggestions: [SkillSuggestion] = []
    /// IDs of suggestions the user has selected to split into.
    var selectedSubSkillIDs: Set<UUID> = []
    /// True while the AI breadth-analysis call is in flight.
    private(set) var isAnalyzingSubSkills = false

    private var analysisTask: Task<Void, Never>? = nil

    /// Cancels any pending analysis and schedules a new one after 800 ms.
    /// Call this whenever `skillName` changes.
    func scheduleAnalysis() {
        analysisTask?.cancel()
        let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 3 else {
            subSkillSuggestions = []
            selectedSubSkillIDs = []
            isAnalyzingSubSkills = false
            return
        }
        analysisTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch {
                return  // cancelled
            }
            isAnalyzingSubSkills = true
            let suggestions = await AIService.shared.analyzeSkillBreadth(
                name: name, category: selectedCategory)
            guard !Task.isCancelled else {
                isAnalyzingSubSkills = false
                return
            }
            subSkillSuggestions = suggestions
            selectedSubSkillIDs = []
            isAnalyzingSubSkills = false
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
        case 2: return "Needs review every ~9 days"
        case 3: return "Needs review every ~7 days"
        case 4: return "Needs review every ~5 days"
        default: return "Needs review every ~3 days"
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
        guard canAdvance else {
            if currentStep == 0 { nameError = "Please enter a skill name." }
            return
        }
        nameError = nil
        let next = nextStep(after: currentStep)
        guard next <= 3 else { return }
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
        if isSplitting {
            let skills = selectedSubSkills.map { sub in
                Skill(name: sub.name, category: sub.category,
                      context: contextText, decayRate: rate)
            }
            skills.forEach { context.insert($0) }
            try? context.save()
            return skills
        } else {
            let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
            let skill = Skill(name: name, category: selectedCategory,
                              context: contextText, decayRate: rate)
            context.insert(skill)
            try? context.save()
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
