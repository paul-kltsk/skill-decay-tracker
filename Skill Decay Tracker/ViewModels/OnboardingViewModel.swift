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
        apiKeyState = ProviderKeychain.store(trimmed, for: selectedProvider) ? .saved : .invalid
    }

    func clearAPIKey() {
        apiKeyText  = ""
        apiKeyState = .missing
    }

    // MARK: - Completion

    /// Persists all onboarding data and marks onboarding as done.
    func complete(context: ModelContext) {
        // 1. Mirror provider selection to UserDefaults for AIService
        selectedProvider.persist()

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

        try? context.save()

        // 4. Mark onboarding complete so it never shows again
        UserDefaults.standard.set(true, forKey: "onboarding.completed")

        // 5. Request notification authorization and schedule the daily reminder
        //    if the user's default preferences have notifications enabled.
        let prefs = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first?.preferences
        Task {
            await NotificationService.shared.requestAuthorization()
            let enabled = prefs?.notificationsEnabled ?? true
            let hour    = prefs?.preferredPracticeTime?.hour   ?? 9
            let minute  = prefs?.preferredPracticeTime?.minute ?? 0
            await NotificationService.shared.syncDailyReminder(
                enabled: enabled, hour: hour, minute: minute)
        }
    }
}
