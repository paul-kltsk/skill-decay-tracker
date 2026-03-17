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

    @State private var viewModel  = SettingsViewModel()
    @State private var editName   = false
    @State private var tempName   = ""

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        List {
            if let profile {
                profileSection(profile)
                aiModelSection(profile)
                navigationLinks(profile)
            }
            dataSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("Settings")
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
        .sheet(isPresented: Binding(
            get:  { viewModel.exportString != nil },
            set:  { if !$0 { viewModel.exportString = nil } }
        )) {
            if let json = viewModel.exportString {
                ExportSheet(json: json)
            }
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
                    // Show the active provider name as trailing hint
                    Text(profile.preferences.aiProvider.displayName)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.sdtSecondary)
                }
            }
        } header: {
            Text("AI Setup")
        } footer: {
            Text("Choose your AI provider and enter an API key. Keys are stored in the device Keychain.")
        }
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

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button {
                viewModel.prepareExport(skills: skills)
            } label: {
                Label("Export Skills as JSON", systemImage: "square.and.arrow.up")
            }
            .disabled(skills.isEmpty)

            Button(role: .destructive) {
                viewModel.showDeleteConfirm = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
                    .foregroundStyle(Color.sdtHealthCritical)
            }
            .disabled(skills.isEmpty)
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("Exported JSON contains skill names, scores, and statistics only.")
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

// MARK: - Export Sheet

private struct ExportSheet: View {
    let json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.sdtPrimary)
                    .padding(SDTSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.sdtBackground)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: json, subject: Text("Skill Decay Tracker Export")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { SettingsView() }
}
