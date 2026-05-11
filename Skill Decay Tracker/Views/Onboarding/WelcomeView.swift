import SwiftUI

/// Onboarding page 1 — animated app logo + tagline.
struct WelcomeView: View {

    let onNext: () -> Void

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated logo
            ZStack {
                ForEach([1.0, 0.6, 0.3], id: \.self) { ring in
                    Circle()
                        .fill(Color.sdtPrimary.opacity(ring * 0.07))
                        .frame(width: 150 + (1.1 - ring) * 70,
                               height: 150 + (1.1 - ring) * 70)
                }
                Circle()
                    .fill(Color.sdtPrimary.opacity(0.12))
                    .frame(width: 124, height: 124)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(Color.sdtPrimary)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            Spacer().frame(height: 48)

            // Title + tagline
            VStack(spacing: SDTSpacing.sm) {
                Text("Skill Decay Tracker")
                    .sdtFont(.titleLarge)
                    .multilineTextAlignment(.center)

                Text("Skills you love,\nhabits that last.")
                    .sdtFont(.titleMedium, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(textOpacity)
            .offset(y: textOpacity == 0 ? 16 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.4), value: textOpacity)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .sdtFont(.bodySemibold, color: Color.sdtOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SDTSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                            .fill(Color.sdtPrimary)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(buttonOpacity)

            Spacer().frame(height: SDTSpacing.xxxl)
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            textOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            buttonOpacity = 1.0
        }
    }
}
