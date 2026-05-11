import SwiftUI

// MARK: - Maintenance View

/// Full-screen view shown when `RemoteConfigService.config.isMaintenanceMode == true`.
///
/// Displays the maintenance message from remote config.
/// Offers a "Try Again" button that re-fetches the config — if maintenance
/// is over, the app automatically proceeds to normal content.
struct MaintenanceView: View {

    // MARK: Dependencies

    let message: String
    let onRetry: () async -> Void

    // MARK: State

    @State private var iconOffset: CGFloat = -20
    @State private var iconOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var contentOpacity: Double = 0
    @State private var isRetrying = false
    @State private var isWrenchWiggling = false

    // MARK: Body

    var body: some View {
        ZStack {
            Color.sdtBackground
                .ignoresSafeArea()

            VStack(spacing: SDTSpacing.xxl) {

                Spacer()

                // Animated icon
                iconView

                // Text content
                textContent

                Spacer()

                // Retry button
                retryButton
                    .padding(.horizontal, SDTSpacing.xl)
                    .padding(.bottom, SDTSpacing.xxxl)
            }
        }
        .task { await animateIn() }
    }

    // MARK: Subviews

    private var iconView: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(Color.sdtHealthFading.opacity(0.12))
                .frame(width: 120, height: 120)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.sdtHealthFading.opacity(0.2), Color.sdtHealthFading.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)

            // Wrench icon with wiggle animation
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.sdtHealthFading)
                .rotationEffect(.degrees(isWrenchWiggling ? 12 : -12))
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isWrenchWiggling
                )
        }
        .offset(y: iconOffset)
        .opacity(iconOpacity)
        .onAppear { isWrenchWiggling = true }
    }

    private var textContent: some View {
        VStack(spacing: SDTSpacing.md) {
            Text("Under Maintenance")
                .sdtFont(.titleLarge)
                .multilineTextAlignment(.center)

            Text(displayMessage)
                .sdtFont(.bodyLarge, color: .sdtSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SDTSpacing.xl)

            // Status chip
            HStack(spacing: SDTSpacing.xs) {
                Circle()
                    .fill(Color.sdtHealthFading)
                    .frame(width: 6, height: 6)
                Text("We'll be back shortly")
                    .sdtFont(.captionSemibold, color: .sdtSecondary)
            }
            .padding(.horizontal, SDTSpacing.md)
            .padding(.vertical, SDTSpacing.xs)
            .background(Color.sdtSurface)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 4)
        }
        .offset(y: contentOffset)
        .opacity(contentOpacity)
    }

    private var retryButton: some View {
        Button {
            Task { await retry() }
        } label: {
            HStack(spacing: SDTSpacing.sm) {
                if isRetrying {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(isRetrying ? "Checking…" : "Try Again")
                    .sdtFont(.bodySemibold, color: .white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: SDTSpacing.minTapTarget + 8)
            .background(isRetrying ? Color.sdtSecondary : Color.sdtPrimary)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
            .animation(.easeInOut(duration: 0.2), value: isRetrying)
        }
        .disabled(isRetrying)
        .offset(y: contentOffset)
        .opacity(contentOpacity)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isRetrying)
    }

    // MARK: Helpers

    private var displayMessage: String {
        message.isEmpty
            ? String(localized: "We're making improvements to give you a better experience. Please check back in a few minutes.")
            : message
    }

    // MARK: Actions

    private func retry() async {
        isRetrying = true
        await onRetry()
        isRetrying = false
    }

    // MARK: Animation

    private func animateIn() async {
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
            iconOffset = 0
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

#Preview("Maintenance — Custom message") {
    MaintenanceView(
        message: "We're rolling out a major update. Back at 18:00 UTC.",
        onRetry: {}
    )
}

#Preview("Maintenance — Default message") {
    MaintenanceView(
        message: "",
        onRetry: {}
    )
}
