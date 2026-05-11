import SwiftUI

// MARK: - AIModelsView

/// Settings screen for choosing an AI provider, managing its API key, and selecting models.
struct AIModelsView: View {

    @Bindable var profile: UserProfile
    @State private var vm = AIModelsViewModel()

    /// Built-in mode: Claude is selected and no personal key is saved.
    private var isBuiltInActive: Bool {
        profile.preferences.aiProvider == .claude && vm.state(for: .claude) != .saved
    }

    /// `true` when the currently active provider has a personal key saved.
    private var isUsingOwnKey: Bool {
        !isBuiltInActive && vm.state(for: profile.preferences.aiProvider) == .saved
    }

    var body: some View {
        List {
            headerSection
            builtInSection
            personalKeySection
            if isUsingOwnKey {
                generationModelSection
                evaluationModelSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("AI Model")
        .navigationBarTitleDisplayMode(.inline)
        .task { vm.loadStatuses() }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                Text("AI for your challenges")
                    .sdtFont(.bodySemibold)
                Text("Use the built-in connection to get started, or add your own API key for unlimited skills and questions — you only pay your AI provider, never us.")
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
            }
            .padding(.vertical, SDTSpacing.sm)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Built-in Section

    private var builtInSection: some View {
        Section {
            BuiltInSettingsCard(isActive: isBuiltInActive) {
                profile.preferences.aiProvider = .claude
                AIProvider.claude.persist()
                SubscriptionService.shared.refreshOwnKeyStatus()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        } header: {
            Text("DEFAULT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.sdtSecondary)
        }
    }

    // MARK: - Personal Key Section

    private var personalKeySection: some View {
        Section {
            ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                ProviderCard(
                    provider: provider,
                    isActive: profile.preferences.aiProvider == provider && !isBuiltInActive,
                    state: vm.state(for: provider),
                    selectedTier: vm.selectedTier,
                    onSelect: {
                        profile.preferences.aiProvider = provider
                        provider.persist()
                        SubscriptionService.shared.refreshOwnKeyStatus()
                    },
                    onSave: { key in
                        vm.save(key: key, for: provider)
                        profile.preferences.aiProvider = provider
                        provider.persist()
                    },
                    onDelete: {
                        vm.delete(for: provider)
                        if profile.preferences.aiProvider == provider {
                            profile.preferences.aiProvider = .claude
                            AIProvider.claude.persist()
                            SubscriptionService.shared.refreshOwnKeyStatus()
                        }
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        } header: {
            Text("PERSONAL API KEY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.sdtSecondary)
        }
    }

    // MARK: - Generation Model Section

    private var generationModelSection: some View {
        Section {
            ModelPicker(selectedTier: $vm.selectedTier,
                        provider: profile.preferences.aiProvider,
                        onSelect: { $0.persist() })
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        } header: {
            Text("GENERATION MODEL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.sdtSecondary)
        } footer: {
            Text("Used to create practice challenges. Higher quality = better questions, higher cost.")
                .font(.system(size: 12))
                .foregroundStyle(Color.sdtSecondary)
        }
    }

    // MARK: - Evaluation Model Section

    private var evaluationModelSection: some View {
        Section {
            ModelPicker(selectedTier: $vm.selectedEvalTier,
                        provider: profile.preferences.aiProvider,
                        onSelect: { $0.persistEval() })
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        } header: {
            Text("EVALUATION MODEL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.sdtSecondary)
        } footer: {
            Text("Used to check your answers. Fast is usually enough — upgrade for nuanced open-ended questions.")
                .font(.system(size: 12))
                .foregroundStyle(Color.sdtSecondary)
        }
    }
}

// MARK: - BuiltInSettingsCard

private struct BuiltInSettingsCard: View {
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            HStack(spacing: SDTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Color.sdtPrimary.opacity(0.12) : Color.sdtBackground)
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isActive ? Color.sdtPrimary : Color.sdtSecondary)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: SDTSpacing.xs) {
                        Text("Built-in AI")
                            .sdtFont(.captionSemibold)
                        Text("Free")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    Text("Claude · No API key required")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.sdtSecondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sdtPrimary)
                        .font(.system(size: 20))
                }
            }

            Text("Challenges are processed through a secure server. No API key needed.")
                .sdtFont(.bodyMedium, color: .sdtSecondary)

            if !isActive {
                Button(action: onSelect) {
                    Text("Use Built-in AI")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.sdtPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SDTSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                                .strokeBorder(Color.sdtPrimary.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SDTSpacing.lg)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                .strokeBorder(
                    isActive ? Color.sdtPrimary.opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - ProviderCard

private struct ProviderCard: View {

    let provider: AIProvider
    let isActive: Bool
    let state: ProviderKeyState
    let selectedTier: AIModelTier
    let onSelect: () -> Void
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @State private var keyText = ""
    @State private var showKeyField = false
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            // Header row
            HStack(spacing: SDTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Color.sdtPrimary.opacity(0.12) : Color.sdtBackground)
                    provider.iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SDTSpacing.xs) {
                        Text(provider.displayName)
                            .sdtFont(.captionSemibold)
                        Text(provider.companyName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                    // Show selected model name when key is active, generic label otherwise
                    if isActive {
                        Text(selectedTier.modelDisplayName(for: provider))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.sdtSecondary)
                    } else {
                        Text(provider.modelLabel)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sdtPrimary)
                        .font(.system(size: 20))
                }
            }

            Text(provider.tagline)
                .sdtFont(.bodyMedium, color: .sdtSecondary)

            // Status + action buttons row
            HStack(spacing: SDTSpacing.sm) {
                KeyStatusBadge(state: state)

                Spacer()

                // Delete button — always visible when a key is saved
                if state == .saved && !showKeyField {
                    Button { showDeleteAlert = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("Remove")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color.red.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showKeyField.toggle()
                        if !showKeyField { keyText = "" }
                    }
                } label: {
                    if showKeyField {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.sdtPrimary)
                    } else if state == .saved {
                        Text("Update Key")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.sdtPrimary)
                    } else {
                        Text("Add Key")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.sdtPrimary)
                    }
                }
            }

            // Expandable key entry form
            if showKeyField {
                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    SecureField("Paste your API key here…", text: $keyText)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(SDTSpacing.sm)
                        .background(Color.sdtBackground)
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))

                    if case .invalid = state {
                        Label("Check the prefix (\(provider.keyPrefix)…) and key length",
                              systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.sdtHealthCritical)
                    }

                    HStack(spacing: SDTSpacing.sm) {
                        Button {
                            onSave(keyText)
                            withAnimation { showKeyField = false }
                            keyText = ""
                        } label: {
                            Text("Save Key")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, SDTSpacing.md)
                                .padding(.vertical, SDTSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                                        .fill(keyText.isEmpty ? Color.sdtSecondary : Color.sdtPrimary)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(keyText.isEmpty)

                        SettingsOpenURLButton(url: provider.apiConsoleURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                Text("Get API Key")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color.sdtPrimary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // "Use {provider}" CTA — shown when a key exists but provider isn't active
            if state == .saved && !isActive && !showKeyField {
                Button(action: onSelect) {
                    Text("Use \(provider.displayName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.sdtPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SDTSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                                .strokeBorder(Color.sdtPrimary.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SDTSpacing.lg)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                .strokeBorder(
                    isActive ? Color.sdtPrimary.opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .confirmationDialog(
            "Remove API Key",
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Remove Key", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the \(provider.displayName) API key from the device keychain.")
        }
    }
}

// MARK: - KeyStatusBadge

private struct KeyStatusBadge: View {
    let state: ProviderKeyState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.color)
                .frame(width: 7, height: 7)
            Text(state.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(state.color)
        }
        .padding(.horizontal, SDTSpacing.sm)
        .padding(.vertical, 4)
        .background(state.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - ProviderKeyState

enum ProviderKeyState: Equatable {
    case saved
    case missing
    case invalid

    var label: String {
        switch self {
        case .saved:   String(localized: "Key saved")
        case .missing: String(localized: "No key")
        case .invalid: String(localized: "Invalid key")
        }
    }

    var color: Color {
        switch self {
        case .saved:   .green
        case .missing: Color.sdtSecondary
        case .invalid: .red
        }
    }
}

// MARK: - ModelPicker

/// Compact model picker showing model name prominently, tier label as badge.
private struct ModelPicker: View {
    @Binding var selectedTier: AIModelTier
    let provider: AIProvider
    let onSelect: (AIModelTier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AIModelTier.allCases, id: \.rawValue) { tier in
                ModelRow(
                    tier: tier,
                    provider: provider,
                    isSelected: selectedTier == tier,
                    onTap: {
                        selectedTier = tier
                        onSelect(tier)
                    }
                )
                if tier != AIModelTier.allCases.last {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .padding(SDTSpacing.sm)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
    }
}

private struct ModelRow: View {
    let tier: AIModelTier
    let provider: AIProvider
    let isSelected: Bool
    let onTap: () -> Void

    private var accentColor: Color {
        switch tier {
        case .fast:     Color.sdtSecondary
        case .balanced: Color.sdtPrimary
        case .best:     Color.orange
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SDTSpacing.md) {
                // Radio button
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? accentColor : Color.sdtSecondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 11, height: 11)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: SDTSpacing.xs) {
                        // Model name is the primary label
                        Text(tier.modelDisplayName(for: provider))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isSelected ? accentColor : Color.sdtPrimary)

                        // Tier badge
                        Text(tier.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isSelected ? accentColor : Color.sdtSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((isSelected ? accentColor : Color.sdtSecondary).opacity(0.1))
                            .clipShape(Capsule())

                        if tier == .balanced {
                            Text("Recommended")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.sdtPrimary.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.sdtPrimary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: SDTSpacing.sm) {
                        Text(tier.qualityDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.sdtSecondary)
                        Spacer()
                        Text(tier.costHint(for: provider))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? accentColor : Color.sdtSecondary)
                        Text("·")
                            .foregroundStyle(Color.sdtSecondary)
                        Text(tier.speedHint)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
            }
            .padding(.vertical, SDTSpacing.sm)
            .padding(.horizontal, SDTSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AIModelsViewModel

@Observable
@MainActor
final class AIModelsViewModel {

    private(set) var keyStates: [AIProvider: ProviderKeyState] = [:]
    var selectedTier: AIModelTier = AIModelTier.persisted
    var selectedEvalTier: AIModelTier = AIModelTier.persistedEval

    func state(for provider: AIProvider) -> ProviderKeyState {
        keyStates[provider] ?? .missing
    }

    func loadStatuses() {
        for provider in AIProvider.allCases {
            keyStates[provider] = ProviderKeychain.has(for: provider) ? .saved : .missing
        }
        selectedTier     = AIModelTier.persisted
        selectedEvalTier = AIModelTier.persistedEval
    }

    func save(key: String, for provider: AIProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider.isValidKey(trimmed) else {
            keyStates[provider] = .invalid
            return
        }
        let stored = ProviderKeychain.store(trimmed, for: provider)
        keyStates[provider] = stored ? .saved : .invalid
        if stored {
            SubscriptionService.shared.refreshOwnKeyStatus()
        }
    }

    func delete(for provider: AIProvider) {
        ProviderKeychain.delete(for: provider)
        keyStates[provider] = .missing
        SubscriptionService.shared.refreshOwnKeyStatus()
    }
}

// MARK: - SettingsOpenURLButton

private struct SettingsOpenURLButton<Label: View>: View {
    @Environment(\.openURL) private var openURL
    let url: URL
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button { openURL(url) } label: { label() }
            .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AIModelsView(profile: {
            let p = UserProfile(displayName: "Dev")
            return p
        }())
    }
}
