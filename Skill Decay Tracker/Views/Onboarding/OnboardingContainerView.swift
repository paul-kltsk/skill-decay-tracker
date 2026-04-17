import SwiftUI

/// Root container for the onboarding flow.
///
/// Shown as a `.fullScreenCover` on first launch. Displays 5 pages in sequence
/// with a custom dot-progress indicator. Calls `onDone` when the user completes
/// or skips all pages so the app can dismiss the cover.
struct OnboardingContainerView: View {

    let onDone: () -> Void

    @State private var vm = OnboardingViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.sdtBackground.ignoresSafeArea()

            Group {
                switch vm.currentPage {
                case 0:
                    WelcomeView(onNext: { vm.nextPage() })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                case 1:
                    HowItWorksView(onNext: { vm.nextPage() })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                case 2:
                    AISetupOnboardingView(vm: vm, onNext: { vm.nextPage() })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                case 3:
                    AddFirstSkillsView(vm: vm, onNext: { vm.nextPage() })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                case 4:
                    ReadyView(vm: vm, onComplete: onDone)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                default:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.currentPage)

            // Page dots (hidden on page 0 and last page — they have their own CTAs)
            if vm.currentPage > 0 && vm.currentPage < OnboardingViewModel.totalPages - 1 {
                PageDots(
                    total: OnboardingViewModel.totalPages,
                    current: vm.currentPage
                )
                .padding(.bottom, SDTSpacing.xxl)
            }
        }
    }
}

// MARK: - Page Dots

private struct PageDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.sdtPrimary : Color.sdtSecondary.opacity(0.35))
                    .frame(width: i == current ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView(onDone: {})
}
