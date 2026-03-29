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

    // MARK: - Export

    /// Builds a JSON string from the current skill portfolio.
    ///
    /// Only top-level skill metadata is exported; challenge history is omitted
    /// to keep the file small and personally identifiable data minimal.
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
