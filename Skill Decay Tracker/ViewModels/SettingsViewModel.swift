import SwiftUI
import SwiftData

// MARK: - SettingsViewModel

/// Manages volatile Settings state that doesn't live in `UserProfile`:
/// JSON export and delete-all-data confirmation.
///
/// API key management has been moved to ``AIModelsViewModel`` / ``AIModelsView``.
@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - Data

    var showDeleteConfirm = false

    // MARK: - Delete All Data

    func deleteAllData(skills: [Skill], context: ModelContext) {
        for skill in skills { context.delete(skill) }
        do { try context.save() } catch {
            #if DEBUG
            print("[\(Self.self)] context.save() failed: \(error)")
            #endif
        }
    }
}
