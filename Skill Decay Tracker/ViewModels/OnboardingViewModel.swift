import SwiftUI
import SwiftData

// MARK: - OnboardingViewModel

/// Drives the multi-page onboarding flow.
///
/// Holds all transient input (name, AI key, first skill) and writes it to
/// SwiftData / Keychain when `complete(context:)` is called on the final page.
@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Navigation

    var currentPage = 0
    static let totalPages = 5

    // MARK: - Page 3: AI Setup

    var selectedProvider: AIProvider = .claude
    var apiKeyText: String = ""
    var apiKeyState: ProviderKeyState = .missing
    var selectedModelTier: AIModelTier = .balanced

    // MARK: - Page 4: First Skill

    var firstSkillName: String = ""
    var firstSkillCategory: SkillCategory = .programming

    // MARK: - Page 5: Profile

    var userName: String = ""

    // MARK: - Navigation

    /// Whether the "Next" / "Continue" button should be enabled.
    var canAdvance: Bool {
        currentPage < Self.totalPages - 1
    }

    func nextPage() {
        guard currentPage < Self.totalPages - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }

    func goTo(page: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = page
        }
    }

    // MARK: - API Key Actions

    func saveAPIKey() {
        let trimmed = apiKeyText.trimmingCharacters(in: .whitespaces)
        guard selectedProvider.isValidKey(trimmed) else {
            apiKeyState = .invalid
            return
        }
        let stored = ProviderKeychain.store(trimmed, for: selectedProvider)
        apiKeyState = stored ? .saved : .invalid
        if stored {
            SubscriptionService.shared.refreshOwnKeyStatus()
        }
    }

    func clearAPIKey() {
        apiKeyText  = ""
        apiKeyState = .missing
    }

    // MARK: - Completion

    /// Persists all onboarding data and marks onboarding as done.
    func complete(context: ModelContext) {
        // 1. Mirror provider and tier selection to UserDefaults for AIService
        selectedProvider.persist()
        selectedModelTier.persist()

        // 2. Update the existing UserProfile
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = (try? context.fetch(descriptor))?.first {
            let name = userName.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { profile.displayName = name }
            profile.preferences.aiProvider = selectedProvider
        }

        // 3. Insert first skill if the user filled it in
        let trimmedSkill = firstSkillName.trimmingCharacters(in: .whitespaces)
        if !trimmedSkill.isEmpty {
            let skill = Skill(name: trimmedSkill, category: firstSkillCategory)
            context.insert(skill)
        }

        do { try context.save() } catch {
            #if DEBUG
            print("[\(Self.self)] context.save() failed: \(error)")
            #endif
        }

        // 4. Analytics
        let aiMode = apiKeyState == .saved ? "personal_key" : "builtin"
        AnalyticsService.onboardingCompleted(
            aiMode: aiMode,
            provider: selectedProvider.rawValue,
            hasFirstSkill: !firstSkillName.trimmingCharacters(in: .whitespaces).isEmpty
        )

        // 5. Mark onboarding complete so it never shows again
        UserDefaults.standard.set(true, forKey: "onboarding.completed")

        // 5. Request notification authorization and schedule the daily reminder.
        //    Snapshot primitive values before entering the Task so no @Model objects
        //    (UserProfile, UserPreferences) are retained past the onboarding context lifetime.
        let prefs   = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first?.preferences
        let enabled = prefs?.notificationsEnabled ?? true
        let hour    = prefs?.preferredPracticeTime?.hour   ?? 9
        let minute  = prefs?.preferredPracticeTime?.minute ?? 0
        Task { [weak self] in
            guard self != nil else { return }
            await NotificationService.shared.requestAuthorization()
            await NotificationService.shared.syncDailyReminder(
                enabled: enabled, hour: hour, minute: minute)
        }
    }
}
