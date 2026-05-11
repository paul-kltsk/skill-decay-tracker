import FirebaseAnalytics

// MARK: - AnalyticsService
//
// Centralised wrapper around Firebase Analytics.
// Firebase constraints: event/param names ≤ 40 chars, snake_case;
// string values ≤ 100 chars; no PII.

enum AnalyticsService {

    // MARK: - Onboarding

    /// User reached the final screen and tapped "Start".
    static func onboardingCompleted(
        aiMode: String,          // "builtin" | "personal_key"
        provider: String,        // "claude" | "openai" | "gemini"
        hasFirstSkill: Bool
    ) {
        Analytics.logEvent("onboarding_completed", parameters: [
            "ai_mode": aiMode,
            "provider": provider,
            "has_first_skill": hasFirstSkill ? 1 : 0,
        ])
    }

    // MARK: - Skills

    /// A skill (or skill split) was saved to SwiftData.
    static func skillAdded(
        category: String,        // SkillCategory.rawValue
        isSplit: Bool,           // true when parent was split into sub-skills
        subskillCount: Int,      // >0 only when isSplit
        difficulty: Int          // 1…5
    ) {
        Analytics.logEvent("skill_added", parameters: [
            "category": category,
            "is_split": isSplit ? 1 : 0,
            "subskill_count": subskillCount,
            "difficulty": difficulty,
        ])
    }

    /// A skill was deleted by the user.
    static func skillDeleted(category: String) {
        Analytics.logEvent("skill_deleted", parameters: [
            "category": category,
        ])
    }

    // MARK: - Practice Sessions

    /// User tapped a session mode and challenges began loading.
    static func sessionStarted(mode: String, challengeCount: Int) {
        Analytics.logEvent("session_started", parameters: [
            "mode": mode,
            "challenge_count": challengeCount,
        ])
    }

    /// All challenges in the session were answered.
    static func sessionCompleted(
        mode: String,
        accuracyPct: Int,        // 0–100
        durationSeconds: Int,
        xpEarned: Int,
        skillCount: Int
    ) {
        Analytics.logEvent("session_completed", parameters: [
            "mode": mode,
            "accuracy_pct": accuracyPct,
            "duration_seconds": durationSeconds,
            "xp_earned": xpEarned,
            "skill_count": skillCount,
        ])
    }

    /// User tapped X / dismissed the session before finishing.
    static func sessionAbandoned(
        mode: String,
        completedChallenges: Int,
        totalChallenges: Int
    ) {
        Analytics.logEvent("session_abandoned", parameters: [
            "mode": mode,
            "completed": completedChallenges,
            "total": totalChallenges,
        ])
    }

    /// User skipped a challenge without answering.
    static func challengeSkipped(mode: String) {
        Analytics.logEvent("challenge_skipped", parameters: [
            "mode": mode,
        ])
    }

    /// User accepted a difficulty-adjustment suggestion at session end.
    static func difficultyAdjusted(direction: String) {   // "increase" | "decrease"
        Analytics.logEvent("difficulty_adjusted", parameters: [
            "direction": direction,
        ])
    }

    // MARK: - Subscriptions & Paywall

    /// Paywall was presented.
    static func paywallShown(trigger: String) {
        Analytics.logEvent("paywall_shown", parameters: [
            "trigger": trigger,
        ])
    }

    /// User tapped a plan card and purchase() was called.
    static func purchaseStarted(productID: String) {
        Analytics.logEvent("purchase_started", parameters: [
            "product_id": productID,
        ])
    }

    /// StoreKit returned a verified transaction — user is now Pro.
    static func purchaseCompleted(productID: String) {
        Analytics.logEvent("purchase_completed", parameters: [
            "product_id": productID,
        ])
    }

    /// Purchase ended with an error (not cancellation).
    static func purchaseFailed(productID: String) {
        Analytics.logEvent("purchase_failed", parameters: [
            "product_id": productID,
        ])
    }

    /// "Restore Purchases" completed.
    static func restoreCompleted(wasPro: Bool) {
        Analytics.logEvent("restore_completed", parameters: [
            "was_pro": wasPro ? 1 : 0,
        ])
    }

    // MARK: - Settings

    /// User switched AI provider or toggled built-in ↔ personal key.
    static func aiProviderChanged(provider: String, mode: String) {
        Analytics.logEvent("ai_provider_changed", parameters: [
            "provider": provider,
            "mode": mode,       // "builtin" | "personal_key"
        ])
    }

    /// User exported their skill data as JSON.
    static func dataExported(skillCount: Int) {
        Analytics.logEvent("data_exported", parameters: [
            "skill_count": skillCount,
        ])
    }

    /// User confirmed deletion of all data.
    static func dataDeleted() {
        Analytics.logEvent("data_deleted", parameters: [:])
    }
}
