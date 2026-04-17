import SwiftUI
import SwiftData

/// ViewModel for ``HomeView``.
///
/// Owns presentation-layer state (sheet flags, deletion confirmation).
/// Reactive data comes from `@Query` in the view; computed analytics
/// are derived by passing the query result into the helper methods below.
///
/// - Important: Must be `@MainActor` because it accesses `@Model` objects
///   and calls `DecayEngine` mutation methods.
@Observable
@MainActor
final class HomeViewModel {

    // MARK: - Sheet / Navigation State

    /// Controls presentation of the Add Skill sheet.
    var showAddSkill = false

    /// Skill pending deletion (drives a confirmation alert).
    var skillPendingDelete: Skill? = nil

    // MARK: - Greeting

    /// Time-appropriate greeting for the current hour.
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date.now)
        switch hour {
        case 5..<12:  return String(localized: "Good morning")
        case 12..<17: return String(localized: "Good afternoon")
        case 17..<22: return String(localized: "Good evening")
        default:      return String(localized: "Good night")
        }
    }

    // MARK: - Analytics (accept @Query result from View)

    /// Average health across all tracked skills, or `0` when empty.
    func portfolioHealth(for skills: [Skill]) -> Double {
        guard !skills.isEmpty else { return 0 }
        return skills.reduce(0) { $0 + $1.healthScore } / Double(skills.count)
    }

    /// Skills whose `nextReviewDate` has passed, sorted by ascending health.
    func overdueSkills(from skills: [Skill]) -> [Skill] {
        skills
            .filter { $0.nextReviewDate <= Date.now }
            .sorted { $0.healthScore < $1.healthScore }
    }

    /// All skills sorted by ascending health score (most critical first).
    func sortedByUrgency(_ skills: [Skill]) -> [Skill] {
        skills.sorted { $0.healthScore < $1.healthScore }
    }

    // MARK: - Health Refresh

    /// Recalculates each skill's health score based on elapsed time.
    ///
    /// Call this on app foreground / `.task` to keep scores current without
    /// requiring a new practice session.
    func refreshHealth(for skills: [Skill]) {
        skills.forEach { DecayEngine.refreshHealth(for: $0) }
    }

    // MARK: - Actions

    /// Deletes a skill from the model context after user confirmation.
    func confirmDelete(context: ModelContext) {
        guard let skill = skillPendingDelete else { return }
        context.delete(skill)
        skillPendingDelete = nil
    }

    /// Pre-generates AI challenges for a newly created skill in the background.
    ///
    /// No-ops if the skill already has challenges (e.g. pre-generated during the
    /// Add Skill confirm step).
    func prefetchChallenges(for skill: Skill, context: ModelContext) {
        guard (skill.challenges ?? []).isEmpty else { return }
        Task { [weak self] in
            // Weak capture: abort if HomeViewModel is released before the AI response arrives.
            guard self != nil else { return }
            do {
                // Extract Sendable scalars on @MainActor before crossing into the AIService actor.
                let skillName       = skill.name
                let skillCategory   = skill.category.rawValue
                let skillDifficulty = skill.effectiveDifficulty
                let skillContext    = skill.context
                let challenges = try await AIService.shared.generateChallenges(
                    skillName: skillName,
                    category: skillCategory,
                    difficulty: skillDifficulty,
                    skillContext: skillContext,
                    count: 3
                )
                for challenge in challenges {
                    skill.challenges = (skill.challenges ?? []) + [challenge]
                    context.insert(challenge)
                }
                do { try context.save() } catch {
            #if DEBUG
            print("[\(Self.self)] context.save() failed: \(error)")
            #endif
        }
            } catch {
                // AIService falls back gracefully; ignore the error here.
            }
        }
    }
}
