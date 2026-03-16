import SwiftUI

/// Daily briefing screen — the app's landing tab.
///
/// Full implementation in Step 3 (HomeViewModel + skill cards + activity feed).
struct HomeView: View {
    var body: some View {
        SDTEmptyState(
            icon: "house.fill",
            title: "Home",
            message: "Coming soon"
        )
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack { HomeView() }
}
