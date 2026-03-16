import SwiftUI

/// A selectable tag/filter chip used in category pickers and filter bars.
///
/// ```swift
/// SDTChip(label: "Programming", systemImage: "chevron.left.forwardslash.chevron.right",
///         isSelected: selectedCategory == .programming,
///         tint: .sdtCategoryProgramming) {
///     selectedCategory = .programming
/// }
/// ```
struct SDTChip: View {

    let label: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var tint: Color = .sdtCategoryProgramming
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: SDTSpacing.xs) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(label)
                    .sdtFont(.captionSemibold, color: isSelected ? .white : .sdtPrimary)
            }
            .padding(.vertical, SDTSpacing.xs)
            .padding(.horizontal, SDTSpacing.md)
            .background(isSelected ? tint : Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip)
                        .strokeBorder(Color.sdtSecondary.opacity(0.3), lineWidth: 1)
                }
            }
        }
        .minTapTarget()
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isSelected)
        .animation(SDTAnimation.scoreChange, value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 8) {
        SDTChip(label: "Swift",
                systemImage: "chevron.left.forwardslash.chevron.right",
                isSelected: true,
                tint: .sdtCategoryProgramming)
        SDTChip(label: "French",
                systemImage: "character.book.closed",
                isSelected: false,
                tint: .sdtCategoryLanguage)
    }
    .padding()
}
