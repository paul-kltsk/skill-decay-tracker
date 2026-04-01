import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseCrashlytics

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
    @State private var remoteConfig = RemoteConfigService()

    // MARK: Container

    /// SwiftData container for all persisted models with CloudKit private database sync.
    ///
    /// Syncs to `iCloud.pavel.kulitski.Skill-Decay-Tracker` private database.
    /// Requires iCloud + CloudKit capability in entitlements (already configured).
    let container: ModelContainer

    init() {
        FirebaseApp.configure()

        let schema = Schema([
            Skill.self,
            Challenge.self,
            ChallengeResult.self,
            UserProfile.self,
            SkillGroup.self,
        ])
        // Try CloudKit sync first; fall back to local-only if iCloud is unavailable
        // (device not signed in, container not yet provisioned, or existing local DB).
        do {
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.pavel.kulitski.Skill-Decay-Tracker")
            )
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            #if DEBUG
            print("[SwiftData] CloudKit init failed (\(error)); falling back to local storage.")
            #endif
            do {
                container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
            } catch {
                fatalError("SwiftData failed to initialize even without CloudKit: \(error)")
            }
        }
    }

    // MARK: Scene

    var body: some Scene {
        WindowGroup {
            RootTabView(selectedTab: $selectedTab)
                .environment(SubscriptionService.shared)
                .environment(remoteConfig)
                .task { await remoteConfig.fetch() }
                .task { await seedProfileIfNeeded() }
                .task { await SubscriptionService.shared.start() }
                .task { WidgetDataService.refresh(context: container.mainContext) }
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
        do { try context.save() } catch {
            #if DEBUG
            print("[\(Self.self)] context.save() failed: \(error)")
            #endif
        }
    }
}

// MARK: - Root Tab View

/// Top-level tab container — extracted to keep `App.body` concise.
private struct RootTabView: View {
    @Binding var selectedTab: AppTab
    @Query private var profiles: [UserProfile]
    @Environment(RemoteConfigService.self) private var remoteConfig

    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    private var colorScheme: ColorScheme? {
        profiles.first?.preferences.theme.colorScheme
    }

    var body: some View {
        Group {
            if remoteConfig.needsForceUpdate {
                ForceUpdateView()
            } else if remoteConfig.config.isMaintenanceMode {
                MaintenanceView(
                    message: remoteConfig.config.maintenanceMessage,
                    onRetry: { await remoteConfig.fetch() }
                )
            } else {
                mainContent
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
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
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { isPresented in if !isPresented { onboardingCompleted = true } }
        )) {
            OnboardingContainerView {
                onboardingCompleted = true
            }
        }
    }
}
