import SwiftUI

/// Practice session launcher — Daily Review / Quick Practice / Deep Dive.
///
/// Full implementation in Step 4 (PracticeViewModel + ChallengeView + feedback loop).
struct SessionLauncherView: View {
    var body: some View {
        SDTEmptyState(
            icon: "bolt.fill",
            title: "Practice",
            message: "Coming soon"
        )
        .navigationTitle("Practice")
    }
}

#Preview {
    NavigationStack { SessionLauncherView() }
}
