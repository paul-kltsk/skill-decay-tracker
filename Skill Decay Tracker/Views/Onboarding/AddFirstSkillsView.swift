import SwiftUI

/// Onboarding page 4 — add the first skill (optional).
struct AddFirstSkillsView: View {

    @Bindable var vm: OnboardingViewModel
    let onNext: () -> Void

    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    // Quick-pick suggestions per category
    private let suggestions: [String] = [
        "Python", "Spanish", "Piano", "Chess", "Drawing",
        "Swift", "History", "Calculus", "Guitar", "Public Speaking"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: SDTSpacing.xxxl)

            // Header
            VStack(spacing: SDTSpacing.sm) {
                Image(systemName: "star.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.sdtHealthThriving)
                    .padding(.bottom, SDTSpacing.xs)
                Text("Add your first skill")
                    .sdtFont(.titleLarge)
                Text("What skill do you want to keep sharp?\nYou can add more anytime.")
                    .sdtFont(.bodyLarge, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: appeared)

            Spacer().frame(height: SDTSpacing.xxl)

            // Skill name input
            VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                TextField("e.g. History of Polish rulers", text: $vm.firstSkillName)
                    .font(.system(size: 16))
                    .padding(SDTSpacing.md)
                    .background(Color.sdtSurface)
                    .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
                    .focused($nameFocused)
                    .submitLabel(.next)

                // Category picker
                Text("Category")
                    .sdtFont(.captionSemibold, color: .sdtSecondary)
                    .padding(.top, SDTSpacing.xs)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SDTSpacing.sm) {
                        ForEach(SkillCategory.allCases, id: \.rawValue) { cat in
                            CategoryChip(
                                category: cat,
                                isSelected: vm.firstSkillCategory == cat
                            ) {
                                vm.firstSkillCategory = cat
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

            Spacer().frame(height: SDTSpacing.lg)

            // Quick-pick suggestions
            VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                Text("Popular picks")
                    .sdtFont(.captionSemibold, color: .sdtSecondary)
                    .padding(.horizontal, SDTSpacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SDTSpacing.sm) {
                        ForEach(suggestions, id: \.self) { s in
                            Button {
                                vm.firstSkillName = s
                                nameFocused = false
                            } label: {
                                Text(s)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.sdtPrimary)
                                    .padding(.horizontal, SDTSpacing.md)
                                    .padding(.vertical, SDTSpacing.xs)
                                    .background(Color.sdtPrimary.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, SDTSpacing.xl)
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

            Spacer()

            // Bottom buttons
            VStack(spacing: SDTSpacing.sm) {
                Button(action: onNext) {
                    Text(vm.firstSkillName.trimmingCharacters(in: .whitespaces).isEmpty
                         ? "Skip for now" : "Continue")
                        .sdtFont(.bodySemibold, color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SDTSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                                .fill(Color.sdtPrimary)
                        )
                }
                .buttonStyle(.plain)

                if !vm.firstSkillName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: onNext) {
                        Text("Skip for now")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.sdtSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SDTSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)

            Spacer().frame(height: SDTSpacing.xxxl)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let category: SkillCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(category.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.sdtPrimary)
                .padding(.horizontal, SDTSpacing.md)
                .padding(.vertical, SDTSpacing.xs)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.sdtPrimary : Color.sdtPrimary.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}

private extension SkillCategory {
    var displayName: String {
        switch self {
        case .programming: "Programming"
        case .language:    "Language"
        case .tool:        "Tool"
        case .concept:     "Concept"
        case .custom:      "Custom"
        }
    }
}
