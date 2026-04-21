import SwiftUI

/// Onboarding page 3 — choose AI mode: built-in (proxy) or personal API key.
///
/// Built-in is pre-selected: no key required, works for everyone including
/// users in regions where AI services are blocked.
struct AISetupOnboardingView: View {

    @Bindable var vm: OnboardingViewModel
    let onNext: () -> Void

    @State private var showPersonalKey = false
    @State private var appeared = false

    /// True when no personal key is saved — proxy/built-in mode is active.
    private var isBuiltInActive: Bool { vm.apiKeyState != .saved }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: SDTSpacing.xxxl)

            VStack(spacing: SDTSpacing.sm) {
                Image(systemName: "cpu")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.sdtPrimary)
                    .padding(.bottom, SDTSpacing.sm)
                Text("Powered by AI")
                    .sdtFont(.titleLarge)
                Text("Use the built-in AI to get started, or bring your own API key for unlimited skills and questions — you only pay your AI provider, never us.")
                    .sdtFont(.bodyLarge, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: appeared)

            Spacer().frame(height: SDTSpacing.xxl)

            VStack(spacing: SDTSpacing.md) {

                // Built-in card (default)
                BuiltInAICard(isSelected: isBuiltInActive) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showPersonalKey = false
                        vm.selectedProvider = .claude
                        vm.clearAPIKey()
                    }
                }

                // Divider
                HStack {
                    Rectangle().fill(Color.sdtSecondary.opacity(0.25)).frame(height: 1)
                    Text("or")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.sdtSecondary)
                        .padding(.horizontal, SDTSpacing.sm)
                    Rectangle().fill(Color.sdtSecondary.opacity(0.25)).frame(height: 1)
                }

                // Personal key toggle / expanded section
                if showPersonalKey {
                    PersonalKeySection(vm: vm) {
                        withAnimation(.easeInOut(duration: 0.25)) { showPersonalKey = false }
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showPersonalKey = true }
                    } label: {
                        HStack(spacing: SDTSpacing.sm) {
                            Image(systemName: "key.fill")
                            Text("Use your own API key")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(vm.apiKeyState == .saved ? .green : Color.sdtPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SDTSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                                .strokeBorder(
                                    vm.apiKeyState == .saved ? Color.green.opacity(0.5) : Color.sdtPrimary.opacity(0.5),
                                    lineWidth: 1.5
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .trailing) {
                        if vm.apiKeyState == .saved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .padding(.trailing, SDTSpacing.md)
                        }
                    }
                }
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

            Spacer()

            VStack(spacing: SDTSpacing.sm) {
                Button(action: onNext) {
                    Text("Continue")
                        .sdtFont(.bodySemibold, color: Color.sdtOnPrimary)
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
            .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)

            Spacer().frame(height: SDTSpacing.xxxl)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - BuiltInAICard

private struct BuiltInAICard: View {
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SDTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.sdtPrimary.opacity(0.12) : Color.sdtBackground)
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.sdtPrimary : Color.sdtSecondary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: SDTSpacing.xs) {
                        Text("Built-in AI")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.sdtPrimary)
                        Text("Free")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                        Text("Recommended")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.sdtPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.sdtPrimary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Text("Claude · Up to 3 skills, 5 questions per session")
                        .font(.system(size: 12))
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

// MARK: - PersonalKeySection

private struct PersonalKeySection: View {
    @Bindable var vm: OnboardingViewModel
    let onClose: () -> Void

    @State private var showKeyField = false

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {

            HStack(spacing: SDTSpacing.sm) {
                ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                    Button {
                        vm.selectedProvider = provider
                        vm.clearAPIKey()
                        showKeyField = false
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: provider.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            Text(provider.displayName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(vm.selectedProvider == provider ? Color.sdtPrimary : Color.sdtSecondary)
                        .padding(.horizontal, SDTSpacing.sm)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(vm.selectedProvider == provider ? Color.sdtPrimary.opacity(0.12) : Color.sdtBackground)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    vm.selectedProvider == provider ? Color.sdtPrimary.opacity(0.5) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.sdtSecondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: SDTSpacing.xs) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.sdtPrimary)
                    .padding(.top, 1)
                Text("Your key is stored securely on this device and unlocks unlimited skills and questions.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.sdtSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if vm.apiKeyState == .saved {
                VStack(alignment: .leading, spacing: SDTSpacing.md) {
                    HStack(spacing: SDTSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("\(vm.selectedProvider.displayName) key saved")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)
                        Spacer()
                        Button {
                            vm.clearAPIKey()
                            showKeyField = true
                        } label: {
                            Text("Change")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.sdtSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(SDTSpacing.sm)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    OnboardingTierPicker(selectedTier: $vm.selectedModelTier,
                                        provider: vm.selectedProvider)
                }
                .transition(.opacity.combined(with: .scale))
            } else if showKeyField {
                keyEntryView
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showKeyField = true }
                } label: {
                    HStack(spacing: SDTSpacing.xs) {
                        Image(systemName: "key.badge.plus")
                        Text("Add \(vm.selectedProvider.displayName) API Key")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.sdtPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SDTSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                            .strokeBorder(Color.sdtPrimary.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SDTSpacing.md)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                .strokeBorder(
                    vm.apiKeyState == .saved ? Color.sdtPrimary.opacity(0.6) : Color.sdtSecondary.opacity(0.2),
                    lineWidth: 1.5
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var keyEntryView: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
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
            .background(Color.sdtBackground)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))

            if vm.apiKeyState == .invalid {
                Label("Invalid key — check the prefix (\(vm.selectedProvider.keyPrefix)…)",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.sdtHealthCritical)
            }

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
                        Image(systemName: "arrow.up.right.square").font(.system(size: 12))
                        Text("Get API Key").font(.system(size: 13, weight: .medium))
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

// MARK: - OnboardingTierPicker

private struct OnboardingTierPicker: View {
    @Binding var selectedTier: AIModelTier
    let provider: AIProvider

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            Text("Model quality")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.sdtSecondary)

            HStack(spacing: SDTSpacing.sm) {
                ForEach(AIModelTier.allCases, id: \.rawValue) { tier in
                    Button {
                        selectedTier = tier
                        tier.persist()
                    } label: {
                        VStack(spacing: 3) {
                            Text(tier.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selectedTier == tier ? tierColor(tier) : Color.sdtSecondary)
                            Text(tier.costHint(for: provider))
                                .font(.system(size: 10))
                                .foregroundStyle(selectedTier == tier ? tierColor(tier).opacity(0.8) : Color.sdtSecondary.opacity(0.7))
                            Text(tier.speedHint)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.sdtSecondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SDTSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTier == tier ? tierColor(tier).opacity(0.1) : Color.sdtBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedTier == tier ? tierColor(tier).opacity(0.5) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tierColor(_ tier: AIModelTier) -> Color {
        switch tier {
        case .fast:     Color.sdtSecondary
        case .balanced: Color.sdtPrimary
        case .best:     Color.orange
        }
    }
}
