import SwiftUI

// MARK: - AIModelsView

/// Settings screen for choosing an AI provider and managing its API key.
struct AIModelsView: View {

    @Bindable var profile: UserProfile
    @State private var vm = AIModelsViewModel()

    /// Built-in mode: Claude is selected and no personal key is saved.
    private var isBuiltInActive: Bool {
        profile.preferences.aiProvider == .claude && vm.state(for: .claude) != .saved
    }

    var body: some View {
        List {
            headerSection
            builtInSection
            personalKeySection
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
                Text("By default, challenges use Claude via a built-in connection — no API key needed. Add your own key for direct access and more privacy.")
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
                    onSelect: {
                        profile.preferences.aiProvider = provider
                        provider.persist()
                    },
                    onSave: { key in
                        vm.save(key: key, for: provider)
                        // Automatically switch to this provider when key is saved
                        profile.preferences.aiProvider = provider
                        provider.persist()
                    },
                    onDelete: {
                        vm.delete(for: provider)
                        // Fall back to built-in if the active provider loses its key
                        if profile.preferences.aiProvider == provider {
                            profile.preferences.aiProvider = .claude
                            AIProvider.claude.persist()
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
    let onSelect: () -> Void
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @State private var keyText = ""
    @State private var showKeyField = false
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            // Header row: icon + name + active badge
            HStack(spacing: SDTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Color.sdtPrimary.opacity(0.12) : Color.sdtBackground)
                    Image(systemName: provider.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isActive ? Color.sdtPrimary : Color.sdtSecondary)
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
                    Text(provider.modelLabel)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.sdtSecondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sdtPrimary)
                        .font(.system(size: 20))
                }
            }

            // Tagline
            Text(provider.tagline)
                .sdtFont(.bodyMedium, color: .sdtSecondary)

            // Key status row
            HStack(spacing: SDTSpacing.sm) {
                KeyStatusBadge(state: state)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showKeyField.toggle()
                        if !showKeyField { keyText = "" }
                    }
                } label: {
                    Text(showKeyField ? "Cancel" : (state == .saved ? "Update Key" : "Add Key"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.sdtPrimary)
                }
            }

            // Inline key field (expandable)
            if showKeyField {
                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    SecureField("Paste your API key here…", text: $keyText)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(SDTSpacing.sm)
                        .background(Color.sdtBackground)
                        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))

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
                        }
                        .disabled(keyText.isEmpty)

                        Link(destination: provider.apiConsoleURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                Text("Get API Key")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color.sdtPrimary)
                        }

                        Spacer()

                        if state == .saved {
                            Button { showDeleteAlert = true } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // "Use this model" button (only when key is saved and not active)
            if state == .saved && !isActive {
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
        case .saved:   "Key saved"
        case .missing: "No key"
        case .invalid: "Invalid key"
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

// MARK: - AIModelsViewModel

@Observable
@MainActor
final class AIModelsViewModel {

    private(set) var keyStates: [AIProvider: ProviderKeyState] = [:]

    func state(for provider: AIProvider) -> ProviderKeyState {
        keyStates[provider] ?? .missing
    }

    func loadStatuses() {
        for provider in AIProvider.allCases {
            keyStates[provider] = ProviderKeychain.has(for: provider) ? .saved : .missing
        }
    }

    func save(key: String, for provider: AIProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider.isValidKey(trimmed) else {
            keyStates[provider] = .invalid
            return
        }
        keyStates[provider] = ProviderKeychain.store(trimmed, for: provider) ? .saved : .invalid
    }

    func delete(for provider: AIProvider) {
        ProviderKeychain.delete(for: provider)
        keyStates[provider] = .missing
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
