import SwiftUI
import SwiftData

// MARK: - API Key Status

enum APIKeyStatus: Equatable {
    case saved
    case missing
    case invalid
    case saving
}

// MARK: - SettingsViewModel

/// Manages volatile Settings state that doesn't live in `UserProfile`:
/// API key (Keychain), JSON export, and delete-all-data confirmation.
@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - API Key

    var apiKeyText:   String      = ""
    var apiKeyStatus: APIKeyStatus = .missing
    var showAPIKeyField: Bool     = false

    // MARK: - Data

    var showDeleteConfirm = false
    var exportString: String? = nil

    // MARK: - Init

    init() {
        apiKeyStatus = ClaudeAPIClient.hasAPIKey() ? .saved : .missing
    }

    // MARK: - API Key Actions

    func saveAPIKey() {
        let trimmed = apiKeyText.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("sk-ant-") else {
            apiKeyStatus = .invalid
            return
        }
        apiKeyStatus = .saving
        let success = ClaudeAPIClient.storeAPIKey(trimmed)
        apiKeyStatus = success ? .saved : .invalid
        if success {
            apiKeyText    = ""
            showAPIKeyField = false
        }
    }

    func removeAPIKey() {
        ClaudeAPIClient.deleteAPIKey()
        apiKeyStatus = .missing
    }

    // MARK: - Export

    /// Builds a JSON string from the current skill portfolio.
    ///
    /// Only top-level skill metadata is exported; challenge history is omitted
    /// to keep the file small and personally identifiable data minimal.
    func prepareExport(skills: [Skill]) {
        struct SkillRow: Encodable {
            let id, name, category: String
            let healthScore: Double
            let peakScore: Double
            let streakDays, totalChallenges: Int
            let accuracy: Double
            let createdAt: String
        }

        let formatter = ISO8601DateFormatter()
        let rows: [SkillRow] = skills.map { s in
            let total   = s.totalPracticeCount
            let correct = s.correctCount
            let acc     = total > 0 ? Double(correct) / Double(total) : 0
            return SkillRow(
                id:               s.id.uuidString,
                name:             s.name,
                category:         s.category.rawValue,
                healthScore:      s.healthScore,
                peakScore:        s.peakScore,
                streakDays:       s.streakDays,
                totalChallenges:  total,
                accuracy:         acc,
                createdAt:        formatter.string(from: s.createdAt)
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(rows),
           let str  = String(data: data, encoding: .utf8) {
            exportString = str
        }
    }

    // MARK: - Delete All Data

    func deleteAllData(skills: [Skill], context: ModelContext) {
        for skill in skills { context.delete(skill) }
        try? context.save()
    }
}
