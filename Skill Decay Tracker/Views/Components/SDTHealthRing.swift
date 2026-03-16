import SwiftUI

/// Circular progress ring that visualises a skill's health score.
///
/// The ring colour automatically tracks the health gradient:
/// Emerald → Teal → Amber → Orange → Rose as health decays.
///
/// ```swift
/// SDTHealthRing(score: skill.healthScore)
///     .frame(width: 56, height: 56)
/// ```
struct SDTHealthRing: View {

    /// Health score in 0…1.
    let score: Double

    /// Stroke width of the ring.
    var lineWidth: CGFloat = 8

    // MARK: Body

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.sdtSecondary.opacity(0.15), lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: score)
                .stroke(
                    Color.sdtHealth(for: score),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(SDTAnimation.scoreChange, value: score)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        ForEach([1.0, 0.8, 0.6, 0.4, 0.2], id: \.self) { score in
            SDTHealthRing(score: score)
                .frame(width: 56, height: 56)
        }
    }
    .padding()
}
