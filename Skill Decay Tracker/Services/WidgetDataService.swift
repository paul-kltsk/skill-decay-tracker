import SwiftData
import WidgetKit

// MARK: - Widget Data Service
//
// Reads skills from SwiftData, converts to lightweight widget models,
// saves to the shared App Groups container, and tells WidgetKit to refresh.
//
// Call `WidgetDataService.refresh(context:)` after any operation that
// changes skill health or practice data:
//   • App launch (in SkillDecayTrackerApp)
//   • After completing a practice session (in PracticeViewModel)
//   • After DecayEngine applies decay (in HomeViewModel)

@MainActor
enum WidgetDataService {

    private static let appGroup = "group.pavel.kulitski.skill-decay-tracker"
    private static let snapshotKey = "sdt.widget.snapshot"

    /// Fetches all skills from SwiftData, builds a ``WidgetSnapshot``,
    /// saves it to the shared container, and reloads all widget timelines.
    static func refresh(context: ModelContext) {
        let skills = (try? context.fetch(FetchDescriptor<Skill>(
            sortBy: [SortDescriptor(\.healthScore, order: .forward)] // worst first
        ))) ?? []

        let widgetSkills = skills.map { skill in
            WidgetSkillData(
                id:                    skill.id.uuidString,
                name:                  skill.name,
                category:              skill.category.rawValue,
                healthScore:           skill.healthScore,
                daysSinceLastPractice: skill.daysSinceLastPractice,
                streakDays:            skill.streakDays
            )
        }

        let maxStreak = skills.map(\.streakDays).max() ?? 0

        let snapshot = WidgetSnapshot(
            skills:    widgetSkills,
            maxStreak: maxStreak,
            updatedAt: .now
        )

        save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Private

    private static func save(_ snapshot: WidgetSnapshot) {
        guard
            let defaults = UserDefaults(suiteName: appGroup),
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
