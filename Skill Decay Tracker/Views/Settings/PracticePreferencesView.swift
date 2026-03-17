import SwiftUI
import SwiftData

/// Practice preference screen.
///
/// Controls daily goal, difficulty preference, and session length.
struct PracticePreferencesView: View {

    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    private let difficultyLabels = ["", "Beginner", "Easy", "Balanced", "Hard", "Expert"]

    var body: some View {
        List {
            // MARK: Daily Goal
            Section {
                HStack {
                    Text("Daily Goal")
                    Spacer()
                    Text("\(profile.preferences.dailyGoalMinutes) min")
                        .sdtFont(.captionSemibold, color: .sdtSecondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(profile.preferences.dailyGoalMinutes) },
                        set: { v in
                            profile.preferences.dailyGoalMinutes = Int(v)
                            try? modelContext.save()
                        }
                    ),
                    in: 5...60,
                    step: 5
                )
                .tint(Color.sdtCategoryProgramming)
            } header: {
                Text("Daily Goal")
            } footer: {
                Text("How many minutes you want to spend practicing per day.")
            }

            // MARK: Difficulty
            Section {
                VStack(alignment: .leading, spacing: SDTSpacing.sm) {
                    HStack {
                        Text("Challenge Difficulty")
                        Spacer()
                        Text(difficultyLabels[profile.preferences.difficultyPreference])
                            .sdtFont(.captionSemibold, color: .sdtCategoryProgramming)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(profile.preferences.difficultyPreference) },
                            set: { v in
                                profile.preferences.difficultyPreference = Int(v.rounded())
                                try? modelContext.save()
                            }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    .tint(Color.sdtCategoryProgramming)

                    HStack {
                        Text("Beginner")
                        Spacer()
                        Text("Expert")
                    }
                    .sdtFont(.caption, color: .sdtSecondary)
                }
                .padding(.vertical, SDTSpacing.xs)
            } header: {
                Text("Challenge Difficulty")
            } footer: {
                Text("The AI tailors question complexity to this level. Your performance also influences future difficulty automatically.")
            }

            // MARK: Session Length
            Section {
                ForEach(SessionLength.allCases) { length in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(length.title)
                                .sdtFont(.bodyMedium)
                            Text(length.subtitle)
                                .sdtFont(.caption, color: .sdtSecondary)
                        }
                        Spacer()
                        if selectedSessionLength == length {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.sdtCategoryProgramming)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSessionLengthRaw = length.rawValue }
                }
            } header: {
                Text("Default Session Length")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.large)
    }

    @AppStorage("preferredSessionLength") private var selectedSessionLengthRaw: String = SessionLength.medium.rawValue

    private var selectedSessionLength: SessionLength {
        get { SessionLength(rawValue: selectedSessionLengthRaw) ?? .medium }
        set { selectedSessionLengthRaw = newValue.rawValue }
    }
}

// MARK: - Session Length

enum SessionLength: String, CaseIterable, Identifiable {
    case quick  = "quick"
    case medium = "medium"
    case deep   = "deep"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick:  "Quick (5 challenges)"
        case .medium: "Medium (10 challenges)"
        case .deep:   "Deep Dive (15 challenges)"
        }
    }

    var subtitle: String {
        switch self {
        case .quick:  "≈ 5 min — great for busy days"
        case .medium: "≈ 10 min — the sweet spot"
        case .deep:   "≈ 20 min — maximum reinforcement"
        }
    }

    var count: Int {
        switch self {
        case .quick:  5
        case .medium: 10
        case .deep:   15
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PracticePreferencesView(profile: UserProfile(displayName: "Preview"))
    }
}
