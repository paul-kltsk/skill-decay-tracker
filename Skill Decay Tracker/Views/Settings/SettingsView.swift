import SwiftUI

/// App settings — notifications, practice preferences, appearance, account.
///
/// Full implementation in Step 7 (NotificationSettingsView + PracticePreferencesView + AppearanceView).
struct SettingsView: View {
    var body: some View {
        SDTEmptyState(
            icon: "gearshape.fill",
            title: "Settings",
            message: "Coming soon"
        )
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
