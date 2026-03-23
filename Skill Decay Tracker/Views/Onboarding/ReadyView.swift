import SwiftUI
import SwiftData

/// Onboarding page 5 — enter name and launch the app.
struct ReadyView: View {

    @Bindable var vm: OnboardingViewModel
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Celebration icon
            ZStack {
                Circle()
                    .fill(Color.sdtHealthThriving.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.sdtHealthThriving)
            }
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.65), value: appeared)

            Spacer().frame(height: SDTSpacing.xxl)

            // Title
            VStack(spacing: SDTSpacing.sm) {
                Text("You're all set!")
                    .sdtFont(.titleLarge)

                Text("One last thing — what should we call you?")
                    .sdtFont(.bodyLarge, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

            Spacer().frame(height: SDTSpacing.xxl)

            // Name field
            TextField("Your first name", text: $vm.userName)
                .font(.system(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(SDTSpacing.lg)
                .background(Color.sdtSurface)
                .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { if !vm.userName.isEmpty { complete() } }
                .padding(.horizontal, SDTSpacing.xl)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)

            Spacer().frame(height: SDTSpacing.sm)

            Text("You can change this later in Settings.")
                .font(.system(size: 12))
                .foregroundStyle(Color.sdtSecondary)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)

            Spacer()

            // Start button
            Button(action: complete) {
                HStack(spacing: SDTSpacing.sm) {
                    Text(vm.userName.trimmingCharacters(in: .whitespaces).isEmpty
                         ? "Start Learning" : "Start Learning, \(vm.userName.trimmingCharacters(in: .whitespaces))!")
                        .sdtFont(.bodySemibold, color: .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SDTSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                        .fill(Color.sdtHealthThriving)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)

            Spacer().frame(height: SDTSpacing.xxxl)
        }
        .task {
            appeared = true
            try? await Task.sleep(for: .milliseconds(600))
            nameFocused = true
        }
    }

    private func complete() {
        nameFocused = false
        vm.complete(context: modelContext)
        onComplete()
    }
}
