import SwiftUI

// MARK: - Skill Suggestion Model

/// A pre-defined skill entry shown in the suggestions picker.
struct SkillSuggestion: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let category: SkillCategory
}

// MARK: - Curated Skill Catalog

extension SkillSuggestion {
    static let all: [SkillSuggestion] = [
        .init(name: "Spanish",          category: .language),
        .init(name: "Mathematics",      category: .concept),
        .init(name: "Public Speaking",  category: .concept),
        .init(name: "Guitar",           category: .tool),
        .init(name: "Python",           category: .programming),
    ]

    /// Suggestions filtered by name substring (case-insensitive).
    static func matching(_ query: String) -> [SkillSuggestion] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }
}

// MARK: - Suggestions View

/// A scrollable list of curated skill suggestions, filtered by the current query.
///
/// Tapping a row calls `onSelect` so ``AddSkillViewModel`` can fill the name and category.
struct SkillSuggestionsView: View {

    let query: String
    var onSelect: (SkillSuggestion) -> Void

    private var suggestions: [SkillSuggestion] { SkillSuggestion.matching(query) }

    var body: some View {
        if suggestions.isEmpty {
            Text("No suggestions match \"\(query)\"")
                .sdtFont(.caption, color: .sdtSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SDTSpacing.xs)
        } else {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: SDTSpacing.md) {
                        Image(systemName: suggestion.category.systemImage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(suggestion.category.color)
                            .frame(width: 24)

                        Text(suggestion.name)
                            .sdtFont(.bodyMedium)

                        Spacer()

                        Text(suggestion.category.displayName)
                            .sdtFont(.caption, color: .sdtSecondary)
                    }
                    .padding(.vertical, SDTSpacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .minTapTarget()

                if suggestion.id != suggestions.last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
    }
}
