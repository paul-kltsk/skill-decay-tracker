import UserNotifications

// MARK: - Notification Service

/// Manages all local notifications for the app: daily practice reminders,
/// critical-decay alerts per skill, and the app badge count.
///
/// **Typical usage:**
/// ```swift
/// // On app foreground / settings change
/// await NotificationService.shared.syncDailyReminder(
///     enabled: prefs.notificationsEnabled,
///     hour: prefs.preferredPracticeTime?.hour ?? 9,
///     minute: prefs.preferredPracticeTime?.minute ?? 0
/// )
/// // After decay engine runs
/// await NotificationService.shared.setBadgeCount(overdueCount)
/// ```
actor NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()
    private init() {}

    // MARK: - Identifiers

    private let dailyReminderID  = "com.sdt.daily-reminder"
    private let decayAlertPrefix = "com.sdt.decay."

    // MARK: - Authorization

    /// Asks the system for alert + badge + sound permission.
    ///
    /// - Returns: `true` if the user grants permission (or it was already granted).
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// The current authorization status without prompting the user.
    var authorizationStatus: UNAuthorizationStatus {
        get async {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    /// `true` when the app has been granted notification permission.
    var isAuthorized: Bool {
        get async { await authorizationStatus == .authorized }
    }

    // MARK: - Daily Reminder

    /// Schedules (or re-schedules) a repeating daily reminder at the given time.
    ///
    /// If authorization status is `.notDetermined`, a system permission dialog
    /// is shown first. If the user denies, the method returns silently.
    func scheduleDailyReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()

        // Always remove the old trigger first so rescheduling works correctly.
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])

        // Request auth on first use; bail if denied or restricted.
        let status = await authorizationStatus
        if status == .notDetermined { await requestAuthorization() }
        guard await isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString(
            "notification.daily.title",
            value: "Time to practice!",
            comment: "Daily reminder notification title"
        )
        content.body = NSLocalizedString(
            "notification.daily.body",
            value: "Keep your knowledge fresh — a quick session takes just a few minutes.",
            comment: "Daily reminder notification body"
        )
        content.sound = .default

        var components = DateComponents()
        components.hour   = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: dailyReminderID,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    /// Cancels the daily reminder without affecting other pending notifications.
    func cancelDailyReminder() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }

    // MARK: - Critical Decay Alerts

    /// Schedules a one-shot decay alert for a skill that has fallen below the
    /// critical health threshold, firing after a 4-hour delay.
    ///
    /// If an alert for this skill is already pending, it is left unchanged to
    /// avoid re-triggering while the user is actively reviewing the skill.
    func scheduleCriticalAlert(skillID: UUID, skillName: String) async {
        guard await isAuthorized else { return }

        let id = decayAlertPrefix + skillID.uuidString

        // Don't re-schedule an already-pending alert for the same skill.
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard !pending.contains(where: { $0.identifier == id }) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(
            format: NSLocalizedString(
                "notification.decay.title",
                value: "%@ is fading",
                comment: "Critical decay alert title — %@ is the skill name"
            ),
            skillName
        )
        content.body = String(
            format: NSLocalizedString(
                "notification.decay.body",
                value: "Your %@ knowledge is at a critical level. A 5-minute session will help restore it.",
                comment: "Critical decay alert body — %@ is the skill name"
            ),
            skillName
        )
        content.sound = .default

        // Fire after 4 h if the user doesn't open the app in the meantime.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4 * 3_600, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Cancels any pending critical decay alert for the given skill
    /// (e.g. after the user completes a practice session for that skill).
    func cancelCriticalAlert(for skillID: UUID) async {
        let id = decayAlertPrefix + skillID.uuidString
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Removes all pending decay alerts (e.g. when notifications are disabled globally).
    func cancelAllCriticalAlerts() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(decayAlertPrefix) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Badge

    /// Sets the app icon badge to the given count (0 clears the badge).
    func setBadgeCount(_ count: Int) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
            // Badge update failed — non-critical, ignore silently.
        }
    }

    // MARK: - Master Sync

    /// Applies the user's current notification preferences to the schedule.
    ///
    /// Call this on:
    /// - App foreground
    /// - Notification toggle change in Settings
    /// - Reminder time change in Settings
    func syncDailyReminder(enabled: Bool, hour: Int, minute: Int) async {
        if enabled {
            await scheduleDailyReminder(hour: hour, minute: minute)
        } else {
            await cancelDailyReminder()
        }
    }
}
