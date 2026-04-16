import SwiftUI
import SwiftData

/// Practice preference screen.
///
/// Controls daily goal, difficulty preference, and session length.
struct PracticePreferencesView: View {

    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var sub

    @State private var showPaywall = false

    private var difficultyLabels: [String] {
        ["", String(localized: "Beginner"), String(localized: "Easy"),
         String(localized: "Balanced"), String(localized: "Hard"), String(localized: "Expert")]
    }

    var body: some View {
        List {
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
                    let isLocked = !sub.isPro && length != .quick
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: SDTSpacing.xs) {
                                Text(length.title)
                                    .sdtFont(.bodyMedium)
                                if isLocked {
                                    ProBadgeLabel()
                                }
                            }
                            Text(length.subtitle)
                                .sdtFont(.caption, color: .sdtSecondary)
                        }
                        Spacer()
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.sdtSecondary.opacity(0.5))
                        } else if selectedSessionLength == length {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.sdtCategoryProgramming)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isLocked {
                            showPaywall = true
                        } else {
                            selectedSessionLengthRaw = length.rawValue
                        }
                    }
                }
            } header: {
                Text("Default Session Length")
            } footer: {
                if !sub.isPro {
                    Text("Medium and Deep Dive sessions require Pro.")
                        .sdtFont(.caption, color: .sdtSecondary)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(trigger: .questionCount)
                    .environment(sub)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sdtBackground)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.large)
    }

    @AppStorage("preferredSessionLength") private var selectedSessionLengthRaw: String = SessionLength.quick.rawValue

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
        case .quick:  String(localized: "Quick (5 challenges)")
        case .medium: String(localized: "Medium (10 challenges)")
        case .deep:   String(localized: "Deep Dive (15 challenges)")
        }
    }

    var subtitle: String {
        switch self {
        case .quick:  String(localized: "≈ 5 min — great for busy days")
        case .medium: String(localized: "≈ 10 min — the sweet spot")
        case .deep:   String(localized: "≈ 20 min — maximum reinforcement")
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
