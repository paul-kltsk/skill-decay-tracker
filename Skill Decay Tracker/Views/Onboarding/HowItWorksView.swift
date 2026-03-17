import SwiftUI

/// Onboarding page 2 — three feature cards explaining the core loop.
struct HowItWorksView: View {

    let onNext: () -> Void

    @State private var appeared = false

    private let features: [(icon: String, color: Color, title: String, detail: String)] = [
        (
            icon: "plus.circle.fill",
            color: Color.sdtCategoryProgramming,
            title: "Add any skill",
            detail: "Piano, Python, Spanish, chess — anything you want to keep sharp. No limits."
        ),
        (
            icon: "sparkles",
            color: Color.sdtPrimary,
            title: "AI generates challenges",
            detail: "Every practice session gets fresh micro-challenges tailored to your skill level."
        ),
        (
            icon: "waveform.path.ecg",
            color: Color.sdtHealthFading,
            title: "Decay keeps you honest",
            detail: "Skills fade without practice. The app tracks every skill's health and reminds you before it drops too low."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: SDTSpacing.xxxl)

            // Header
            VStack(spacing: SDTSpacing.sm) {
                Text("How it works")
                    .sdtFont(.titleLarge)
                    .multilineTextAlignment(.center)
                Text("Three steps to never forgetting what matters.")
                    .sdtFont(.bodyLarge, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4), value: appeared)

            Spacer().frame(height: SDTSpacing.xxxl)

            // Feature cards
            VStack(spacing: SDTSpacing.lg) {
                ForEach(features.indices, id: \.self) { i in
                    FeatureRow(
                        icon: features[i].icon,
                        color: features[i].color,
                        title: features[i].title,
                        detail: features[i].detail
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.45).delay(0.15 + Double(i) * 0.1), value: appeared)
                }
            }
            .padding(.horizontal, SDTSpacing.xl)

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .sdtFont(.bodySemibold, color: .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SDTSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                            .fill(Color.sdtPrimary)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.6), value: appeared)

            Spacer().frame(height: SDTSpacing.xxxl)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: SDTSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .sdtFont(.bodySemibold)
                Text(detail)
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
