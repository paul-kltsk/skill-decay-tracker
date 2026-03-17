import SwiftUI

// MARK: - AIModelsView

/// Settings screen for choosing an AI provider and managing its API key.
///
/// Each provider card shows:
/// - Provider name, company, model label
/// - Current key status badge
/// - Inline ``SecureField`` for entering / updating the key
/// - "Get API Key" link to the provider's console (beginner-friendly)
struct AIModelsView: View {

    @Bindable var profile: UserProfile
    @State private var vm = AIModelsViewModel()

    var body: some View {
        List {
            headerSection
            ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                ProviderCard(
                    provider: provider,
                    isActive: profile.preferences.aiProvider == provider,
                    state: vm.state(for: provider),
                    onSelect: {
                        profile.preferences.aiProvider = provider
                        provider.persist()
                    },
                    onSave: { key in
                        vm.save(key: key, for: provider)
                    },
                    onDelete: {
                        vm.delete(for: provider)
                    }
                )
                .listRowBackground(Color.sdtSurface)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("AI Model")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.loadStatuses() }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                Text("Choose your AI provider")
                    .sdtFont(.bodySemibold)
                Text("The selected model generates practice challenges and evaluates your answers. You need an API key from the provider — it's free to get started.")
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
            }
            .padding(.vertical, SDTSpacing.sm)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
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
                Image(systemName: provider.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isActive ? Color.sdtPrimary : Color.sdtSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isActive ? Color.sdtPrimary.opacity(0.12) : Color.sdtBackground)
                    )

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

                // Active checkmark
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
                // Toggle key field
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
                        // Save button
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

                        // "Get API Key" link — beginner-friendly
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

                        // Delete key (only when one is saved)
                        if state == .saved {
                            Button {
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // "Use this model" button (only when not active)
            if !isActive {
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
            Button("Remove Key", role: .destructive) {
                onDelete()
            }
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
        if ProviderKeychain.store(trimmed, for: provider) {
            keyStates[provider] = .saved
        } else {
            keyStates[provider] = .invalid
        }
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
