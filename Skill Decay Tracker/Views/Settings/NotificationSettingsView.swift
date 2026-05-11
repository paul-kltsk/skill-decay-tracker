import SwiftUI
import SwiftData

/// Notification preferences screen.
///
/// Mutates `profile.preferences` directly — SwiftData persists
/// each change immediately via `@Observable`.
struct NotificationSettingsView: View {

    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let h = profile.preferences.preferredPracticeTime?.hour   ?? 9
                let m = profile.preferences.preferredPracticeTime?.minute ?? 0
                return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                profile.preferences.preferredPracticeTime = PracticeTimePreference(
                    hour:   c.hour   ?? 9,
                    minute: c.minute ?? 0
                )
                try? modelContext.save()
            }
        )
    }

    var body: some View {
        List {
            // MARK: Daily Reminders
            Section {
                Toggle("Daily Practice Reminder", isOn: Binding(
                    get: { profile.preferences.notificationsEnabled },
                    set: { enabled in
                        profile.preferences.notificationsEnabled = enabled
                        try? modelContext.save()
                        Task {
                            let hour   = profile.preferences.preferredPracticeTime?.hour   ?? 9
                            let minute = profile.preferences.preferredPracticeTime?.minute ?? 0
                            await NotificationService.shared.syncDailyReminder(
                                enabled: enabled, hour: hour, minute: minute)
                            if !enabled {
                                await NotificationService.shared.cancelAllCriticalAlerts()
                            }
                        }
                    }
                ))

                if profile.preferences.notificationsEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection:   reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: profile.preferences.preferredPracticeTime) { _, time in
                        let hour   = time?.hour   ?? 9
                        let minute = time?.minute ?? 0
                        Task {
                            await NotificationService.shared.scheduleDailyReminder(
                                hour: hour, minute: minute)
                        }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("You'll get a gentle nudge if you haven't practiced by your chosen time.")
            }

            // MARK: Decay Alerts
            Section {
                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    HStack {
                        Text("Critical Alert Threshold")
                        Spacer()
                        Text("\(Int(criticalThreshold * 100))%")
                            .sdtFont(.captionSemibold, color: .sdtSecondary)
                    }
                    Slider(value: $criticalThreshold, in: 0.1...0.5, step: 0.05)
                        .tint(Color.sdtHealthCritical)
                    Text("Alert when a skill drops below this health score.")
                        .sdtFont(.caption, color: .sdtSecondary)
                }
                .padding(.vertical, SDTSpacing.xs)
            } header: {
                Text("Decay Alerts")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }

    // Stored in AppStorage since UserPreferences doesn't have this field yet
    @AppStorage("criticalAlertThreshold") private var criticalThreshold: Double = 0.30
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView(profile: UserProfile(displayName: "Preview"))
    }
}
