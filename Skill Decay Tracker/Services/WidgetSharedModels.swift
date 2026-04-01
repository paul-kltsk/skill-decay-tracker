import Foundation

// MARK: - Widget Shared Models
//
// These structs are intentionally duplicated in both targets:
//   • Main app  (this file)      — written by WidgetDataService
//   • Widget extension           — read by SDTWidgetModels / SDTProvider
//
// Both sides use the same JSON keys via Codable, so they interoperate
// through the shared App Groups UserDefaults container.
// If you add a field here, add it in SDTWidgetModels.swift too.

struct WidgetSkillData: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let healthScore: Double
    let daysSinceLastPractice: Double
    let streakDays: Int
}

struct WidgetSnapshot: Codable {
    let skills: [WidgetSkillData]
    let maxStreak: Int
    let updatedAt: Date
}
