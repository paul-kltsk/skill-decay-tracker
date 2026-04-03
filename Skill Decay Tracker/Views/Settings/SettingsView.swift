import SwiftUI
import SwiftData

/// Tab 5 — Settings.
///
/// Sections:
/// 1. Profile  — display name, XP/level
/// 2. AI Model — NavigationLink to ``AIModelsView`` (provider + key management)
/// 3. Notifications → NavigationLink
/// 4. Practice      → NavigationLink
/// 5. Appearance    → NavigationLink
/// 6. Data & Privacy — JSON export, delete all data
/// 7. About          — app version
struct SettingsView: View {

    @Query private var profiles: [UserProfile]
    @Query(sort: \Skill.name) private var skills: [Skill]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var sub

    @State private var viewModel  = SettingsViewModel()
    @State private var editName   = false
    @State private var tempName   = ""
    @State private var showPaywall = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        List {
            if let profile {
                profileSection(profile)
                aiModelSection(profile)
                navigationLinks(profile)
            }
            subscriptionSection
            dataSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: .generic)
        }
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Delete All Data",
            isPresented: $viewModel.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                viewModel.deleteAllData(skills: skills, context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All skills, challenges, and history will be permanently removed. This cannot be undone.")
        }
    }

    // MARK: - Profile Section

    private func profileSection(_ profile: UserProfile) -> some View {
        Section {
            HStack(spacing: SDTSpacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.sdtCategoryProgramming.opacity(0.15))
                    Text(profile.displayName.isEmpty
                         ? "?"
                         : String(profile.displayName.prefix(1)).uppercased())
                        .sdtFont(.titleSmall, color: .sdtCategoryProgramming)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    if editName {
                        TextField("Your name", text: $tempName)
                            .sdtFont(.bodySemibold)
                            .onSubmit { saveName(to: profile) }
                    } else {
                        Text(profile.displayName.isEmpty ? "Set your name" : profile.displayName)
                            .sdtFont(.bodySemibold,
                                     color: profile.displayName.isEmpty ? .sdtSecondary : .sdtPrimary)
                    }
                    Text("Level \(profile.level) · \(profile.xp) XP")
                        .sdtFont(.caption, color: .sdtSecondary)
                }

                Spacer()

                if editName {
                    Button("Save") { saveName(to: profile) }
                        .sdtFont(.captionSemibold, color: .sdtCategoryProgramming)
                } else {
                    Button("Edit") {
                        tempName = profile.displayName
                        editName = true
                    }
                    .sdtFont(.caption, color: .sdtSecondary)
                }
            }
            .padding(.vertical, SDTSpacing.xs)

            // XP Progress bar
            VStack(alignment: .leading, spacing: SDTSpacing.xs) {
                HStack {
                    Text("Progress to Level \(profile.level + 1)")
                        .sdtFont(.caption, color: .sdtSecondary)
                    Spacer()
                    Text("\(profile.xpToNextLevel - profile.xp) XP to go")
                        .sdtFont(.caption, color: .sdtSecondary)
                }
                SDTProgressBar(value: profile.levelProgress, tint: .sdtCategoryProgramming)
                    .frame(height: 5)
            }
        } header: {
            Text("Profile")
        }
    }

    private func saveName(to profile: UserProfile) {
        profile.displayName = tempName.trimmingCharacters(in: .whitespaces)
        try? modelContext.save()
        editName = false
    }

    // MARK: - AI Model Section

    @ViewBuilder
    private func aiModelSection(_ profile: UserProfile) -> some View {
        Section {
            NavigationLink {
                AIModelsView(profile: profile)
            } label: {
                HStack(spacing: SDTSpacing.md) {
                    Label("AI Model", systemImage: "cpu")
                    Spacer()
                    // Show "Built-in · Claude" when no personal key is saved
                    Text(aiModeLabel(for: profile))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.sdtSecondary)
                }
            }
        } header: {
            Text("AI Setup")
        } footer: {
            Text("By default, Claude is used via a built-in connection — no API key needed. Add your own key for a direct connection.")
        }
    }

    // MARK: - AI Mode Label

    private func aiModeLabel(for profile: UserProfile) -> String {
        let provider = profile.preferences.aiProvider
        guard ProviderKeychain.has(for: provider) else {
            return "Built-in · Claude"
        }
        return "\(provider.displayName) · My Key"
    }

    // MARK: - Navigation Links

    @ViewBuilder
    private func navigationLinks(_ profile: UserProfile) -> some View {
        Section {
            NavigationLink {
                NotificationSettingsView(profile: profile)
            } label: {
                Label("Notifications", systemImage: "bell.badge")
            }

            NavigationLink {
                PracticePreferencesView(profile: profile)
            } label: {
                Label("Practice", systemImage: "bolt")
            }

            NavigationLink {
                AppearanceView(profile: profile)
            } label: {
                Label("Appearance", systemImage: "paintbrush")
            }
        } header: {
            Text("Preferences")
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            if sub.isPro {
                HStack {
                    Label("Pro Subscriber", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Color.sdtPrimary)
                    Spacer()
                    ProBadgeLabel()
                }
                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(Color.sdtSecondary)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Label("Upgrade to Pro", systemImage: "star.fill")
                            .foregroundStyle(Color.sdtPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.sdtSecondary.opacity(0.5))
                    }
                }
            }
        } header: {
            Text("Subscription")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showDeleteConfirm = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
                    .foregroundStyle(Color.sdtHealthCritical)
            }
            .disabled(skills.isEmpty)
        } header: {
            Text("Data & Privacy")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(Color.sdtSecondary)
            }
        } header: {
            Text("About")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}


// MARK: - Preview

#Preview {
    NavigationStack { SettingsView() }
}
