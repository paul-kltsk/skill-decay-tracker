import SwiftUI
import CloudKit

// MARK: - Remote Config Model

/// App-wide configuration fetched from CloudKit public database on launch.
///
/// Enables emergency kill-switches, force-update prompts, and feature flags
/// without requiring an App Store release.
///
/// **CloudKit setup (one-time):**
/// 1. Open https://icloud.developer.apple.com → your container
/// 2. Schema → Record Types → Create `RemoteConfig`
/// 3. Add fields: `minimumVersion` (String), `isMaintenanceMode` (Int64),
///    `maintenanceMessage` (String), `isAIEnabled` (Int64),
///    `maxFreeSkills` (Int64), `maxFreeChallengesPerDay` (Int64)
/// 4. Records → Public Database → Add one record with initial values
/// 5. To update: edit that record in the dashboard — changes apply on next app launch
struct AppRemoteConfig {
    /// Minimum app version required. If current version is lower → ForceUpdateView.
    let minimumVersion: String
    /// When `true`, app shows MaintenanceView and blocks all interaction.
    let isMaintenanceMode: Bool
    /// Message displayed on MaintenanceView.
    let maintenanceMessage: String
    /// Kill-switch for Claude API. When `false`, AI features are disabled.
    let isAIEnabled: Bool
    /// Maximum number of skills for free tier users.
    let maxFreeSkills: Int
    /// Maximum AI challenges per day for free tier users.
    let maxFreeChallengesPerDay: Int

    /// Safe defaults used when CloudKit is unreachable.
    static let defaults = AppRemoteConfig(
        minimumVersion: "0.0.0",
        isMaintenanceMode: false,
        maintenanceMessage: "",
        isAIEnabled: true,
        maxFreeSkills: 3,
        maxFreeChallengesPerDay: 5
    )
}

// MARK: - Remote Config Service

/// Fetches and caches remote configuration from CloudKit public database.
///
/// Usage:
/// ```swift
/// @State private var remoteConfig = RemoteConfigService()
/// // In .task:
/// await remoteConfig.fetch()
/// // Check state:
/// if remoteConfig.needsForceUpdate { ... }
/// ```
@Observable
@MainActor
final class RemoteConfigService {

    // MARK: Public State

    /// Current effective configuration (fetched or defaults).
    private(set) var config: AppRemoteConfig = .defaults

    /// `true` while the initial fetch is in progress.
    private(set) var isLoading = false

    /// Whether the installed app version is below `config.minimumVersion`.
    var needsForceUpdate: Bool {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return current.compare(config.minimumVersion, options: .numeric) == .orderedAscending
    }

    // MARK: Private

    private let cacheKey = "sdt.remoteConfig.cache"

    /// CloudKit container is registered — remote config is now active.
    private let cloudKitEnabled = true

    // MARK: Fetch

    /// Fetches config from CloudKit public database.
    /// Falls back to local cache, then to `AppRemoteConfig.defaults` if unavailable.
    func fetch() async {
        guard cloudKitEnabled else {
            loadFromCache()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let publicDB = CKContainer.default().publicCloudDatabase
            let query = CKQuery(
                recordType: "RemoteConfig",
                predicate: NSPredicate(value: true)
            )
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            guard let record = results.first.flatMap({ try? $0.1.get() }) else {
                loadFromCache()
                return
            }

            let fetched = AppRemoteConfig(
                minimumVersion:          record["minimumVersion"] as? String ?? AppRemoteConfig.defaults.minimumVersion,
                isMaintenanceMode:       (record["isMaintenanceMode"] as? Int64 ?? 0) == 1,
                maintenanceMessage:      record["maintenanceMessage"] as? String ?? "",
                isAIEnabled:             (record["isAIEnabled"] as? Int64 ?? 1) == 1,
                maxFreeSkills:           Int(record["maxFreeSkills"] as? Int64 ?? 3),
                maxFreeChallengesPerDay: Int(record["maxFreeChallengesPerDay"] as? Int64 ?? 5)
            )

            config = fetched
            saveToCache(fetched)

        } catch {
            // Silently fall back — app must never crash due to missing config
            loadFromCache()
        }
    }

    // MARK: Cache (UserDefaults)

    private func saveToCache(_ config: AppRemoteConfig) {
        let dict: [String: Any] = [
            "minimumVersion":          config.minimumVersion,
            "isMaintenanceMode":       config.isMaintenanceMode,
            "maintenanceMessage":      config.maintenanceMessage,
            "isAIEnabled":             config.isAIEnabled,
            "maxFreeSkills":           config.maxFreeSkills,
            "maxFreeChallengesPerDay": config.maxFreeChallengesPerDay
        ]
        UserDefaults.standard.set(dict, forKey: cacheKey)
    }

    private func loadFromCache() {
        guard let dict = UserDefaults.standard.dictionary(forKey: cacheKey) else { return }
        config = AppRemoteConfig(
            minimumVersion:          dict["minimumVersion"] as? String ?? AppRemoteConfig.defaults.minimumVersion,
            isMaintenanceMode:       dict["isMaintenanceMode"] as? Bool ?? false,
            maintenanceMessage:      dict["maintenanceMessage"] as? String ?? "",
            isAIEnabled:             dict["isAIEnabled"] as? Bool ?? true,
            maxFreeSkills:           dict["maxFreeSkills"] as? Int ?? 3,
            maxFreeChallengesPerDay: dict["maxFreeChallengesPerDay"] as? Int ?? 5
        )
    }
}
