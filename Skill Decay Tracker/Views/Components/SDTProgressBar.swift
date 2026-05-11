import SwiftUI

/// A thin animated horizontal progress bar.
///
/// Used for XP level progress, session completion, and any linear metric.
///
/// ```swift
/// SDTProgressBar(value: profile.levelProgress, tint: .sdtCategoryProgramming)
///     .frame(height: 4)
/// ```
struct SDTProgressBar: View {

    /// Progress value in 0…1.
    let value: Double

    /// Bar fill colour. Defaults to the SDT primary accent.
    var tint: Color = .sdtCategoryProgramming

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.sdtSecondary.opacity(0.15))

                // Fill
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * max(0, min(1, value)))
                    .animation(SDTAnimation.scoreChange, value: value)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        SDTProgressBar(value: 0.3, tint: .sdtHealthCritical)
        SDTProgressBar(value: 0.6, tint: .sdtHealthFading)
        SDTProgressBar(value: 0.85, tint: .sdtHealthHealthy)
        SDTProgressBar(value: 1.0, tint: .sdtHealthThriving)
    }
    .frame(height: 6)
    .padding()
}
