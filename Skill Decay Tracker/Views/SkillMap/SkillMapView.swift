import SwiftUI

/// Constellation / grid view of all skills.
///
/// Full implementation in Step 5 (SkillMapViewModel + ConstellationView + SkillGridView).
struct SkillMapView: View {
    var body: some View {
        SDTEmptyState(
            icon: "sparkles",
            title: "Skills",
            message: "Coming soon"
        )
        .navigationTitle("Skills")
    }
}

#Preview {
    NavigationStack { SkillMapView() }
}
