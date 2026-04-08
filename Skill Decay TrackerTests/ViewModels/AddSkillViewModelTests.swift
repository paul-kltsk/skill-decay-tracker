import Testing
import SwiftData
import Foundation
@testable import Skill_Decay_Tracker

// MARK: - Tags

extension Tag {
    @Tag static var viewModel: Self
    @Tag static var navigation: Self
}

// MARK: - AddSkillViewModel Tests

@Suite("AddSkillViewModel", .tags(.viewModel))
@MainActor
struct AddSkillViewModelTests {

    // MARK: - canAdvance

    @Suite("canAdvance", .tags(.viewModel))
    @MainActor
    struct CanAdvanceTests {

        @Test("canAdvance is false when name is empty")
        func falseWhenNameEmpty() {
            let vm = AddSkillViewModel()
            vm.skillName = ""
            #expect(!vm.canAdvance)
        }

        @Test("canAdvance is false when name is only whitespace")
        func falseWhenNameWhitespace() {
            let vm = AddSkillViewModel()
            vm.skillName = "   "
            #expect(!vm.canAdvance)
        }

        @Test("canAdvance is true when name has content")
        func trueWhenNameFilled() {
            let vm = AddSkillViewModel()
            vm.skillName = "Swift"
            #expect(vm.canAdvance)
        }

        @Test("canAdvance is always true on steps 1-3")
        func alwaysTrueOnLaterSteps() {
            let vm = AddSkillViewModel()
            vm.skillName = "Swift"
            for step in 1...3 {
                vm.currentStep = step
                #expect(vm.canAdvance, "canAdvance must be true on step \(step)")
            }
        }
    }

    // MARK: - Normal navigation (no splitting)

    @Suite("Normal navigation", .tags(.viewModel, .navigation))
    @MainActor
    struct NormalNavigationTests {

        @Test("advance() increments step from 0 to 1")
        func advanceFromZero() {
            let vm = AddSkillViewModel()
            vm.skillName = "Swift"
            vm.advance()
            #expect(vm.currentStep == 1)
        }

        @Test("advance() goes 0 → 1 → 2 → 3 → 4")
        func advanceFullFlow() {
            let vm = AddSkillViewModel()
            vm.skillName = "Swift"
            vm.advance(); #expect(vm.currentStep == 1)
            vm.advance(); #expect(vm.currentStep == 2)
            vm.advance(); #expect(vm.currentStep == 3)
            vm.advance(); #expect(vm.currentStep == 4)
        }

        @Test("advance() does not go past step 4")
        func advanceDoesNotExceedMax() {
            let vm = AddSkillViewModel()
            vm.skillName = "Swift"
            vm.currentStep = 4
            vm.advance()
            #expect(vm.currentStep == 4)
        }

        @Test("back() decrements step 3 → 2 → 1 → 0")
        func backFullFlow() {
            let vm = AddSkillViewModel()
            vm.currentStep = 3
            vm.back(); #expect(vm.currentStep == 2)
            vm.back(); #expect(vm.currentStep == 1)
            vm.back(); #expect(vm.currentStep == 0)
        }

        @Test("back() does not go below 0")
        func backDoesNotGoBelowZero() {
            let vm = AddSkillViewModel()
            vm.back()
            #expect(vm.currentStep == 0)
        }

        @Test("advance() on step 0 with empty name does not advance")
        func advanceWithEmptyNameDoesNotAdvance() {
            let vm = AddSkillViewModel()
            vm.skillName = ""
            vm.advance()
            #expect(vm.currentStep == 0)
        }

        @Test("advance() clears nameError on success")
        func advanceClearsError() {
            let vm = AddSkillViewModel()
            vm.skillName = ""
            vm.advance()                  // sets error
            vm.skillName = "Python"
            vm.advance()                  // clears error
            #expect(vm.nameError == nil)
            #expect(vm.currentStep == 1)
        }
    }

    // MARK: - Focus suggestions

    @Suite("Focus suggestions", .tags(.viewModel))
    @MainActor
    struct FocusSuggestionsTests {

        @Test("focusSuggestions is empty by default")
        func emptyByDefault() {
            let vm = AddSkillViewModel()
            #expect(vm.focusSuggestions.isEmpty)
        }

        @Test("isAnalyzingFocus is false by default")
        func notAnalyzingByDefault() {
            let vm = AddSkillViewModel()
            #expect(!vm.isAnalyzingFocus)
        }

        @Test("scheduleNameAnalysis clears focusSuggestions immediately")
        func scheduleClearsSuggestions() {
            let vm = AddSkillViewModel()
            let suggestion = SkillSuggestion(name: "Memory management", category: .programming)
            vm.focusSuggestions = [suggestion]
            vm.skillName = "Swift"
            vm.scheduleNameAnalysis()
            // Suggestions should be cleared synchronously on schedule
            #expect(vm.focusSuggestions.isEmpty)
        }

        @Test("advance() from step 0 always goes to step 1 (no skipping)")
        func advanceFromNameAlwaysGoesToCategory() {
            let vm = AddSkillViewModel()
            vm.skillName = "Swift"
            // Even with focus suggestions present, navigation is always linear
            vm.focusSuggestions = [SkillSuggestion(name: "Memory management", category: .programming)]
            vm.advance()
            #expect(vm.currentStep == 1)
        }

        @Test("back() from step 2 goes to step 1 (no skipping)")
        func backFromDifficultyGoesToCategory() {
            let vm = AddSkillViewModel()
            vm.currentStep = 2
            vm.back()
            #expect(vm.currentStep == 1)
        }
    }

    // MARK: - Difficulty decay rate

    @Suite("difficultyDecayRate", .tags(.viewModel))
    @MainActor
    struct DifficultyDecayRateTests {

        @Test("Difficulty 1 maps to ~0.05")
        func difficulty1() {
            let vm = AddSkillViewModel()
            vm.initialDifficulty = 1
            #expect(abs(vm.difficultyDecayRate - 0.05) < 1e-10)
        }

        @Test("Difficulty 3 maps to ~0.10")
        func difficulty3() {
            let vm = AddSkillViewModel()
            vm.initialDifficulty = 3
            #expect(abs(vm.difficultyDecayRate - 0.10) < 1e-6,
                    "Difficulty 3 should map to 0.10, got \(vm.difficultyDecayRate)")
        }

        @Test("Difficulty 5 maps to ~0.18")
        func difficulty5() {
            let vm = AddSkillViewModel()
            vm.initialDifficulty = 5
            #expect(abs(vm.difficultyDecayRate - 0.18) < 1e-10)
        }

        @Test("Rate increases monotonically with difficulty")
        func rateMonotonic() {
            let vm = AddSkillViewModel()
            var previous = Double(0)
            for d in [1.0, 2.0, 3.0, 4.0, 5.0] {
                vm.initialDifficulty = d
                let rate = vm.difficultyDecayRate
                #expect(rate > previous, "Rate at difficulty \(d) (\(rate)) must be > \(previous)")
                previous = rate
            }
        }
    }

    // MARK: - apply(suggestion:)

    @Suite("apply(suggestion:)", .tags(.viewModel))
    @MainActor
    struct ApplySuggestionTests {

        @Test("apply sets skillName and selectedCategory from suggestion")
        func applySetsFields() {
            let vm = AddSkillViewModel()
            let suggestion = SkillSuggestion(name: "Japanese", category: .language)
            vm.apply(suggestion: suggestion)
            #expect(vm.skillName == "Japanese")
            #expect(vm.selectedCategory == .language)
        }
    }
}
