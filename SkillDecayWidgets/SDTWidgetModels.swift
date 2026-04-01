import SwiftUI
import WidgetKit

// MARK: - App Group

let sdtAppGroup = "group.pavel.kulitski.skill-decay-tracker"

// MARK: - Data Models

/// Lightweight snapshot of a single skill for use in widget views.
/// Codable so it can be stored in shared UserDefaults.
struct WidgetSkillData: Codable, Identifiable {
    let id: String
    let name: String
    let category: String       // SkillCategory.rawValue
    let healthScore: Double
    let daysSinceLastPractice: Double
    let streakDays: Int
}

/// Full snapshot written by the main app and read by all widgets.
struct WidgetSnapshot: Codable {
    /// All skills sorted by healthScore ascending (most urgent first).
    let skills: [WidgetSkillData]
    /// Maximum streakDays across all skills.
    let maxStreak: Int
    let updatedAt: Date

    static let placeholder = WidgetSnapshot(
        skills: [
            WidgetSkillData(id: "1", name: "Swift",   category: "Programming", healthScore: 0.38, daysSinceLastPractice: 6, streakDays: 3),
            WidgetSkillData(id: "2", name: "SwiftUI", category: "Programming", healthScore: 0.61, daysSinceLastPractice: 3, streakDays: 1),
            WidgetSkillData(id: "3", name: "SQL",     category: "Tool",        healthScore: 0.82, daysSinceLastPractice: 1, streakDays: 7),
        ],
        maxStreak: 7,
        updatedAt: Date()
    )

    var mostUrgent: WidgetSkillData? { skills.first }
}

// MARK: - Shared Data Store

/// Reads and writes widget data via the App Groups shared container.
enum WidgetDataStore {
    private static let key = "sdt.widget.snapshot"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: sdtAppGroup) }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot {
        guard
            let data = defaults?.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}

// MARK: - Timeline Entry + Provider

struct SDTEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Shared TimelineProvider used by all SDT widgets.
struct SDTProvider: TimelineProvider {
    func placeholder(in context: Context) -> SDTEntry {
        SDTEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SDTEntry) -> Void) {
        completion(SDTEntry(date: .now, snapshot: WidgetDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SDTEntry>) -> Void) {
        let snapshot = WidgetDataStore.load()
        // 8 entries × 30 min = 4 hours coverage; system refreshes at .atEnd
        let entries = (0..<8).map { offset -> SDTEntry in
            let date = Calendar.current.date(byAdding: .minute, value: offset * 30, to: .now)!
            return SDTEntry(date: date, snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Color Helpers

extension Color {
    /// Health-tier color matching the main app's design system.
    static func sdtHealth(_ score: Double) -> Color {
        switch score {
        case 0.9...: return Color(hex: "059669")
        case 0.7...: return Color(hex: "0D9488")
        case 0.5...: return Color(hex: "D97706")
        case 0.3...: return Color(hex: "EA580C")
        default:     return Color(hex: "E11D48")
        }
    }

    /// Category accent color matching the main app's design system.
    static func sdtCategory(_ category: String) -> Color {
        switch category {
        case "Programming": return Color(hex: "6366F1")
        case "Language":    return Color(hex: "8B5CF6")
        case "Tool":        return Color(hex: "0EA5E9")
        case "Concept":     return Color(hex: "D946EF")
        default:            return Color(hex: "64748B")
        }
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Formatting Helpers

func sdtHealthLabel(_ score: Double) -> String {
    switch score {
    case 0.9...: return "Thriving"
    case 0.7...: return "Healthy"
    case 0.5...: return "Fading"
    case 0.3...: return "Wilting"
    default:     return "Critical"
    }
}

func sdtDaysAgo(_ days: Double) -> String {
    let d = Int(days)
    switch d {
    case 0:  return "Today"
    case 1:  return "Yesterday"
    default: return "\(d)d ago"
    }
}
