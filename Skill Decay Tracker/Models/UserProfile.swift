import Foundation
import SwiftData

// MARK: - App Theme

/// The user's preferred color scheme.
///
/// `Sendable` — passed across actor boundaries when applying appearance settings.
enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"
}

// MARK: - Practice Time Preference

/// A time-of-day preference for practice reminders (hour + minute in 0…23 / 0…59).
///
/// Stored as a `Codable` value type so it serialises cleanly inside ``UserPreferences``.
struct PracticeTimePreference: Codable, Sendable, Equatable {
    var hour: Int
    var minute: Int

    static let defaultMorning = PracticeTimePreference(hour: 9, minute: 0)
}

// MARK: - User Preferences

/// Serialisable user preferences stored inside ``UserProfile``.
///
/// `Sendable` — value type with all-`Sendable` stored properties; safe to pass
/// across actor boundaries without triggering Swift 6 data-race diagnostics.
struct UserPreferences: Sendable, Equatable {
    /// Whether the app should send practice reminder notifications.
    var notificationsEnabled: Bool
    /// Preferred time of day for reminders, or `nil` when notifications are off.
    var preferredPracticeTime: PracticeTimePreference?
    /// Preferred challenge difficulty on a 1–5 scale (3 = balanced).
    var difficultyPreference: Int
    /// The user's chosen color scheme.
    var theme: AppTheme
    /// Whether haptic feedback is enabled.
    var hapticsEnabled: Bool
    /// The AI provider used for challenge generation and evaluation.
    var aiProvider: AIProvider

    init() {
        notificationsEnabled  = true
        preferredPracticeTime = .defaultMorning
        difficultyPreference  = 3
        theme                 = .system
        hapticsEnabled        = true
        aiProvider            = .claude
    }
}

// Custom decoder — tolerates missing keys from older stored data.
// nonisolated breaks the @MainActor inference from aiProvider's Codable synthesis.
nonisolated extension UserPreferences: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notificationsEnabled  = (try c.decodeIfPresent(Bool.self,                   forKey: .notificationsEnabled))  ?? true
        preferredPracticeTime =  try c.decodeIfPresent(PracticeTimePreference.self, forKey: .preferredPracticeTime)
        difficultyPreference  = (try c.decodeIfPresent(Int.self,                    forKey: .difficultyPreference))  ?? 3
        theme                 = (try c.decodeIfPresent(AppTheme.self,               forKey: .theme))                 ?? .system
        hapticsEnabled        = (try c.decodeIfPresent(Bool.self,                   forKey: .hapticsEnabled))        ?? true
        aiProvider            = (try c.decodeIfPresent(AIProvider.self,             forKey: .aiProvider))            ?? .claude
    }
}

// MARK: - UserProfile

/// The single user profile record for the app.
///
/// There should be exactly one `UserProfile` in the store; access it via
/// `#Predicate<UserProfile> { _ in true }` and fetch the first result.
///
/// XP and level are purely presentational — they don't affect the decay algorithm.
@Model
final class UserProfile {

    // MARK: Identity

    var id: UUID
    var createdAt: Date
    var lastActiveDate: Date

    // MARK: Display

    var displayName: String

    // MARK: Gamification

    /// Accumulated experience points across all practice sessions.
    var xp: Int
    /// Current level derived from XP thresholds (computed by ``DecayEngine``).
    var level: Int
    /// The longest streak (days) the user has ever achieved across all skills.
    var longestStreakDays: Int
    /// Total number of practice sessions completed.
    var totalSessionsCompleted: Int

    // MARK: Preferences

    /// Stored as `Codable` — SwiftData encodes this as a single blob column.
    var preferences: UserPreferences

    // MARK: Subscription

    /// `true` when the user has an active Pro or Lifetime entitlement.
    var isPro: Bool

    // MARK: Init

    init(displayName: String) {
        self.id                    = UUID()
        self.createdAt             = Date.now
        self.lastActiveDate        = Date.now
        self.displayName           = displayName
        self.xp                    = 0
        self.level                 = 1
        self.longestStreakDays      = 0
        self.totalSessionsCompleted = 0
        self.preferences           = UserPreferences()
        self.isPro                 = false
    }

    // MARK: Computed Helpers

    /// XP required to reach the next level.
    ///
    /// Threshold grows quadratically: level N requires `N² × 100` total XP.
    var xpToNextLevel: Int {
        let nextLevel = level + 1
        return nextLevel * nextLevel * 100
    }

    /// Progress towards the next level in 0…1.
    var levelProgress: Double {
        let currentThreshold = level * level * 100
        let nextThreshold    = xpToNextLevel
        let span             = nextThreshold - currentThreshold
        guard span > 0 else { return 1 }
        return Double(xp - currentThreshold) / Double(span)
    }
}
