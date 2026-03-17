import SwiftUI

/// Onboarding page 3 — choose AI provider and enter API key.
///
/// The key step is optional — users can skip it and add a key later in Settings.
struct AISetupOnboardingView: View {

    @Bindable var vm: OnboardingViewModel
    let onNext: () -> Void

    @State private var showKeyField = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: SDTSpacing.xxxl)

            // Header
            VStack(spacing: SDTSpacing.sm) {
                Image(systemName: "cpu")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.sdtPrimary)
                    .padding(.bottom, SDTSpacing.sm)
                Text("Choose your AI")
                    .sdtFont(.titleLarge)
                Text("Pick the model that generates your challenges.\nAll three are excellent — choose what you have.")
                    .sdtFont(.bodyLarge, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: appeared)

            Spacer().frame(height: SDTSpacing.xxl)

            // Provider picker
            VStack(spacing: SDTSpacing.md) {
                ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                    OnboardingProviderRow(
                        provider: provider,
                        isSelected: vm.selectedProvider == provider
                    ) {
                        vm.selectedProvider = provider
                        vm.clearAPIKey()
                        showKeyField = false
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(
                        .easeOut(duration: 0.4).delay(0.1 + Double(AIProvider.allCases.firstIndex(of: provider) ?? 0) * 0.08),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, SDTSpacing.xl)

            Spacer().frame(height: SDTSpacing.xl)

            // API Key section
            VStack(spacing: SDTSpacing.md) {
                if showKeyField {
                    keyEntryField
                } else {
                    addKeyButton
                }

                // Status badge when key is saved
                if vm.apiKeyState == .saved {
                    HStack(spacing: SDTSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Key saved securely in Keychain")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)

            Spacer()

            // Bottom buttons
            VStack(spacing: SDTSpacing.sm) {
                Button(action: onNext) {
                    Text(vm.apiKeyState == .saved ? "Continue" : "Continue")
                        .sdtFont(.bodySemibold, color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SDTSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                                .fill(Color.sdtPrimary)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Text("Skip for now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.sdtSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)

            Spacer().frame(height: SDTSpacing.xxxl)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Key Entry

    private var addKeyButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { showKeyField = true }
        } label: {
            HStack(spacing: SDTSpacing.sm) {
                Image(systemName: "key.badge.plus")
                Text("Add API Key")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.sdtPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                    .strokeBorder(Color.sdtPrimary.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var keyEntryField: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            // SecureField
            HStack(spacing: SDTSpacing.sm) {
                Image(systemName: "key.fill")
                    .foregroundStyle(Color.sdtSecondary)
                    .font(.system(size: 14))
                SecureField(vm.selectedProvider.keyPrefix + "…", text: $vm.apiKeyText)
                    .font(.system(size: 14, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit { vm.saveAPIKey() }
            }
            .padding(SDTSpacing.md)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))

            if vm.apiKeyState == .invalid {
                Label("Invalid key — check the prefix (\(vm.selectedProvider.keyPrefix)…)",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.sdtHealthCritical)
            }

            // Buttons row
            HStack(spacing: SDTSpacing.sm) {
                Button {
                    withAnimation { vm.saveAPIKey() }
                } label: {
                    Text("Save Key")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, SDTSpacing.lg)
                        .padding(.vertical, SDTSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                                .fill(vm.apiKeyText.isEmpty ? Color.sdtSecondary : Color.sdtPrimary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(vm.apiKeyText.isEmpty)

                Link(destination: vm.selectedProvider.apiConsoleURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                        Text("Get API Key")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.sdtPrimary)
                }

                Spacer()

                Button {
                    withAnimation { showKeyField = false; vm.clearAPIKey() }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.sdtSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - OnboardingProviderRow

private struct OnboardingProviderRow: View {
    let provider: AIProvider
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SDTSpacing.md) {
                Image(systemName: provider.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.sdtPrimary : Color.sdtSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.sdtPrimary.opacity(0.12) : Color.sdtBackground)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SDTSpacing.xs) {
                        Text(provider.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.sdtPrimary)
                        Text("by \(provider.companyName)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                    Text(provider.modelLabel)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.sdtSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sdtPrimary)
                        .font(.system(size: 20))
                }
            }
            .padding(SDTSpacing.md)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                    .strokeBorder(
                        isSelected ? Color.sdtPrimary.opacity(0.6) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
