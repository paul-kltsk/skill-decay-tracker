import SwiftUI
import SwiftData

// MARK: - App Tab

/// Type-safe tab identifier for `TabView(selection:)`.
enum AppTab: Hashable {
    case home
    case skillMap
    case practice
    case analytics
    case settings
}

// MARK: - Entry Point

@main
struct SkillDecayTrackerApp: App {

    @State private var selectedTab: AppTab = .home

    // MARK: Container

    /// SwiftData container for all persisted models.
    ///
    /// CloudKit sync is planned but not yet active (team entitlements pending).
    /// To enable, replace `ModelConfiguration()` with:
    /// ```swift
    /// ModelConfiguration(cloudKitDatabase: .private("iCloud.pavel.kulitski.Skill-Decay-Tracker"))
    /// ```
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Skill.self,
                Challenge.self,
                ChallengeResult.self,
                UserProfile.self,
                SkillGroup.self,
            ])
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            fatalError("SwiftData failed to initialize: \(error)")
        }
    }

    // MARK: Scene

    var body: some Scene {
        WindowGroup {
            RootTabView(selectedTab: $selectedTab)
                .environment(SubscriptionService.shared)
                .task { await seedProfileIfNeeded() }
                .task { await SubscriptionService.shared.start() }
        }
        .modelContainer(container)
    }

    // MARK: First-Launch Seed

    /// Inserts a blank `UserProfile` on first launch if none exists.
    @MainActor
    private func seedProfileIfNeeded() async {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard count == 0 else { return }
        context.insert(UserProfile(displayName: ""))
        try? context.save()
    }
}

// MARK: - Root Tab View

/// Top-level tab container — extracted to keep `App.body` concise.
private struct RootTabView: View {
    @Binding var selectedTab: AppTab
    @Query private var profiles: [UserProfile]

    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    private var colorScheme: ColorScheme? {
        profiles.first?.preferences.theme.colorScheme
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            Tab("Skills", systemImage: "sparkles", value: AppTab.skillMap) {
                NavigationStack { SkillMapView() }
            }
            Tab("Practice", systemImage: "bolt.fill", value: AppTab.practice) {
                NavigationStack { SessionLauncherView() }
            }
            Tab("Analytics", systemImage: "chart.bar.fill", value: AppTab.analytics) {
                NavigationStack { AnalyticsView() }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .preferredColorScheme(colorScheme)
        .fullScreenCover(isPresented: .constant(!onboardingCompleted)) {
            OnboardingContainerView {
                onboardingCompleted = true
            }
        }
    }
}
