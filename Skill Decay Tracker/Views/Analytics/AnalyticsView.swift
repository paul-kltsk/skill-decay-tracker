import SwiftUI

/// Portfolio health trends, per-skill comparison, achievements.
///
/// Full implementation in Step 6 (AnalyticsViewModel + Swift Charts + TimeIntelligenceView).
struct AnalyticsView: View {
    var body: some View {
        SDTEmptyState(
            icon: "chart.bar.fill",
            title: "Analytics",
            message: "Coming soon"
        )
        .navigationTitle("Analytics")
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
}
