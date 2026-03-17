import SwiftUI
import SwiftData

/// Appearance settings: color scheme, haptics.
///
/// The selected theme is written to `UserProfile.preferences.theme` via SwiftData.
/// ``RootTabView`` reads it and applies `.preferredColorScheme(_:)` globally.
struct AppearanceView: View {

    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            // MARK: Theme
            Section {
                ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                    HStack {
                        Label {
                            Text(theme.displayName)
                        } icon: {
                            Image(systemName: theme.systemImage)
                                .foregroundStyle(
                                    profile.preferences.theme == theme
                                        ? Color.sdtCategoryProgramming
                                        : Color.sdtSecondary
                                )
                        }

                        Spacer()

                        if profile.preferences.theme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.sdtCategoryProgramming)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        profile.preferences.theme = theme
                        try? modelContext.save()
                    }
                }
            } header: {
                Text("Color Scheme")
            } footer: {
                Text("Changes apply immediately across the entire app.")
            }

            // MARK: Haptics
            Section {
                Toggle("Haptic Feedback", isOn: Binding(
                    get: { profile.preferences.hapticsEnabled },
                    set: { v in
                        profile.preferences.hapticsEnabled = v
                        try? modelContext.save()
                    }
                ))
            } header: {
                Text("Feedback")
            } footer: {
                Text("Subtle vibrations on challenge results and interactions.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - AppTheme Helpers

extension AppTheme {
    var displayName: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max"
        case .dark:   "moon.stars"
        }
    }

    /// Maps to SwiftUI `ColorScheme?` for `.preferredColorScheme(_:)`.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AppearanceView(profile: UserProfile(displayName: "Preview"))
    }
}
