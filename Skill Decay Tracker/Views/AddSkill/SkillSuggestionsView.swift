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
        // ── Languages (universal, highest demand) ──
        .init(name: "Spanish",              category: .language),
        .init(name: "English",              category: .language),
        .init(name: "French",               category: .language),
        .init(name: "German",               category: .language),
        .init(name: "Japanese",             category: .language),
        .init(name: "Mandarin",             category: .language),
        .init(name: "Korean",               category: .language),
        .init(name: "Arabic",               category: .language),
        .init(name: "Italian",              category: .language),
        .init(name: "Portuguese",           category: .language),
        .init(name: "Hindi",                category: .language),
        .init(name: "Turkish",              category: .language),

        // ── Academic / Science ──
        .init(name: "Mathematics",          category: .concept),
        .init(name: "Algebra",              category: .concept),
        .init(name: "Calculus",             category: .concept),
        .init(name: "Physics",              category: .concept),
        .init(name: "Chemistry",            category: .concept),
        .init(name: "Biology",              category: .concept),
        .init(name: "History",              category: .concept),
        .init(name: "Geography",            category: .concept),
        .init(name: "Economics",            category: .concept),
        .init(name: "Psychology",           category: .concept),
        .init(name: "Philosophy",           category: .concept),

        // ── Professional & Business ──
        .init(name: "Public Speaking",      category: .concept),
        .init(name: "Marketing Strategy",   category: .concept),
        .init(name: "Copywriting",          category: .concept),
        .init(name: "Project Management",   category: .concept),
        .init(name: "Personal Finance",     category: .concept),
        .init(name: "Investing",            category: .concept),
        .init(name: "Negotiation",          category: .concept),
        .init(name: "Data Analysis",        category: .concept),

        // ── Creative & Arts ──
        .init(name: "Drawing",              category: .tool),
        .init(name: "Photography",          category: .tool),
        .init(name: "Graphic Design",       category: .tool),
        .init(name: "Video Editing",        category: .tool),
        .init(name: "Music Theory",         category: .concept),
        .init(name: "Guitar",               category: .tool),
        .init(name: "Piano",                category: .tool),
        .init(name: "Singing",              category: .concept),

        // ── Programming (for developers) ──
        .init(name: "Python",               category: .programming),
        .init(name: "JavaScript",           category: .programming),
        .init(name: "Swift",                category: .programming),
        .init(name: "SQL",                  category: .programming),
        .init(name: "React",                category: .programming),
        .init(name: "Machine Learning",     category: .programming),
        .init(name: "Git",                  category: .tool),
        .init(name: "Docker",               category: .tool),
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
