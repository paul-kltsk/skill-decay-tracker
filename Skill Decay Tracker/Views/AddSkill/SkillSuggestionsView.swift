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
        // Programming
        .init(name: "Swift",             category: .programming),
        .init(name: "Python",            category: .programming),
        .init(name: "JavaScript",        category: .programming),
        .init(name: "TypeScript",        category: .programming),
        .init(name: "SwiftUI",           category: .programming),
        .init(name: "React",             category: .programming),
        .init(name: "SQL",               category: .programming),
        .init(name: "Rust",              category: .programming),
        .init(name: "Go",                category: .programming),
        .init(name: "Kotlin",            category: .programming),

        // Language
        .init(name: "Spanish",           category: .language),
        .init(name: "French",            category: .language),
        .init(name: "German",            category: .language),
        .init(name: "Japanese",          category: .language),
        .init(name: "Mandarin",          category: .language),
        .init(name: "Arabic",            category: .language),
        .init(name: "Italian",           category: .language),
        .init(name: "Portuguese",        category: .language),

        // Tool
        .init(name: "Git",               category: .tool),
        .init(name: "Docker",            category: .tool),
        .init(name: "Vim",               category: .tool),
        .init(name: "Xcode",             category: .tool),
        .init(name: "Figma",             category: .tool),
        .init(name: "Kubernetes",        category: .tool),
        .init(name: "Terraform",         category: .tool),
        .init(name: "Bash",              category: .tool),

        // Concept
        .init(name: "Machine Learning",  category: .concept),
        .init(name: "System Design",     category: .concept),
        .init(name: "Algorithms",        category: .concept),
        .init(name: "Data Structures",   category: .concept),
        .init(name: "Concurrency",       category: .concept),
        .init(name: "REST APIs",         category: .concept),
        .init(name: "SwiftData",         category: .concept),
        .init(name: "Networking",        category: .concept),
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
            Text("No suggestions match "\(query)"")
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

                        Text(suggestion.category.rawValue)
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
