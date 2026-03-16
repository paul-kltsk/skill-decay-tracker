import SwiftUI
import SwiftData

/// ViewModel for the 4-step ``AddSkillView`` sheet.
///
/// **Step flow:**
/// 1. Name — free-text entry with live validation
/// 2. Category — grid selection
/// 3. Initial difficulty — slider that sets starting `decayRate`
/// 4. Confirm — review and save
@Observable
@MainActor
final class AddSkillViewModel {

    // MARK: - Step State

    /// The currently visible step (0-indexed, 0…3).
    var currentStep: Int = 0

    // MARK: - Step 1: Name

    var skillName: String = ""
    var nameError: String? = nil

    /// Trims whitespace and checks for emptiness.
    var isNameValid: Bool {
        !skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Step 2: Category

    var selectedCategory: SkillCategory = .programming

    // MARK: - Step 3: Difficulty

    /// Perceived learning difficulty: 1 (easy) → 5 (hard).
    ///
    /// Maps to `decayRate`:
    /// | Level | Rate  | Meaning                        |
    /// |-------|-------|--------------------------------|
    /// | 1     | 0.05  | Easy — decays slowly           |
    /// | 3     | 0.10  | Medium — default rate          |
    /// | 5     | 0.18  | Hard — needs frequent practice |
    var initialDifficulty: Double = 3

    var difficultyDecayRate: Double {
        // Linear interpolation: D1→0.05, D3→0.10, D5→0.18
        let t = (initialDifficulty - 1) / 4   // 0…1
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

    /// Whether the current step's required fields are satisfied.
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
        guard currentStep < 3 else { return }
        currentStep += 1
    }

    func back() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    // MARK: - Save

    /// Creates and persists a new ``Skill`` from the wizard's state.
    ///
    /// - Returns: The inserted `Skill` so the caller can trigger AI pre-fetch.
    @discardableResult
    func save(context: ModelContext) -> Skill {
        let trimmedName = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let skill = Skill(
            name: trimmedName,
            category: selectedCategory,
            decayRate: difficultyDecayRate
        )
        context.insert(skill)
        try? context.save()
        return skill
    }

    // MARK: - Quick-fill from Suggestion

    /// Fills the name and category from a tapped suggestion.
    func apply(suggestion: SkillSuggestion) {
        skillName        = suggestion.name
        selectedCategory = suggestion.category
    }
}
