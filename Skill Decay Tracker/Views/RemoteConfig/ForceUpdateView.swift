import SwiftUI

// MARK: - Force Update View

/// Full-screen blocking view shown when the installed app version is below
/// the server-required minimum (`RemoteConfigService.needsForceUpdate == true`).
///
/// Opens the App Store page when the user taps "Update Now".
/// The user cannot dismiss this screen — update is mandatory.
struct ForceUpdateView: View {

    // MARK: State

    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var contentOpacity: Double = 0
    @State private var isPulsing = false

    // MARK: Body

    var body: some View {
        ZStack {
            // Background
            Color.sdtBackground
                .ignoresSafeArea()

            VStack(spacing: SDTSpacing.xxl) {

                Spacer()

                // Icon
                iconView

                // Text content
                textContent

                Spacer()

                // Action button
                actionButton
                    .padding(.horizontal, SDTSpacing.xl)
                    .padding(.bottom, SDTSpacing.xxxl)
            }
        }
        .task { await animateIn() }
    }

    // MARK: Subviews

    private var iconView: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Color.sdtHealthCritical.opacity(0.15))
                .frame(width: 120, height: 120)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            // Icon background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.sdtHealthCritical.opacity(0.2), Color.sdtHealthWilting.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)

            // SF Symbol
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.sdtHealthCritical)
        }
        .scaleEffect(iconScale)
        .opacity(iconOpacity)
        .onAppear { isPulsing = true }
    }

    private var textContent: some View {
        VStack(spacing: SDTSpacing.md) {
            Text("Update Required")
                .sdtFont(.titleLarge)
                .multilineTextAlignment(.center)

            Text("A new version of Skill Decay Tracker is available with important improvements and fixes.")
                .sdtFont(.bodyLarge, color: .sdtSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SDTSpacing.xl)
        }
        .offset(y: contentOffset)
        .opacity(contentOpacity)
    }

    private var actionButton: some View {
        Button {
            openAppStore()
        } label: {
            HStack(spacing: SDTSpacing.sm) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 17, weight: .semibold))
                Text("Update Now")
                    .sdtFont(.bodySemibold, color: .white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: SDTSpacing.minTapTarget + 8)
            .background(Color.sdtHealthCritical)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
        }
        .offset(y: contentOffset)
        .opacity(contentOpacity)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: contentOpacity == 1)
    }

    // MARK: Actions

    private func openAppStore() {
        UIApplication.shared.open(AppConstants.URLs.appStore)
    }

    // MARK: Animation

    private func animateIn() async {
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
            contentOffset = 0
            contentOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Force Update") {
    ForceUpdateView()
}
