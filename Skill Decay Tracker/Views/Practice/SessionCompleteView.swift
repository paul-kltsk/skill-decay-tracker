import StoreKit
import SwiftData
import SwiftUI

/// Shown when all challenges in a session are answered.
///
/// Displays accuracy, XP earned, skills reviewed, and session duration.
struct SessionCompleteView: View {

    let summary: SessionSummary
    var onApplyAdjustment: ((DifficultyAdjustment) -> Void)? = nil
    let onDone: () -> Void

    @State private var appeared = false
    /// IDs of adjustments the user has already acted on (accepted or dismissed).
    @State private var resolvedAdjustments: Set<UUID> = []

    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SDTSpacing.xl) {
                    header
                    statsGrid
                    difficultyAdjustmentsSection
                    skillsReviewed
                }
                .padding(.horizontal, SDTSpacing.lg)
                .padding(.top, SDTSpacing.xxxl)
                .padding(.bottom, SDTSpacing.xxxl)
            }

            doneButton
                .padding(.horizontal, SDTSpacing.lg)
                .padding(.bottom, SDTSpacing.xl)
        }
        .background(Color.sdtBackground)
        .onAppear {
            withAnimation(SDTAnimation.scoreChange.delay(0.1)) { appeared = true }
            recordCompletedSession()
        }
    }

    // MARK: - Session Tracking

    private func recordCompletedSession() {
        guard let profile = profiles.first else { return }
        profile.totalSessionsCompleted += 1
        try? modelContext.save()

        let count = profile.totalSessionsCompleted
        // Request a review on the 3rd, 10th, and 25th successful session.
        // "Successful" = accuracy ≥ 60%. Apple limits prompts to 3× per year;
        // these milestones stay well within that cap.
        let milestones = [3, 10, 25]
        if milestones.contains(count) && summary.accuracy >= 0.6 {
            requestReview()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: SDTSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.sdtHealthThriving, Color.sdtHealthHealthy],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 96, height: 96)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .animation(SDTAnimation.scoreChange, value: appeared)

                Image(systemName: "star.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1 : 0.2)
                    .animation(SDTAnimation.scoreChange.delay(0.1), value: appeared)
            }

            VStack(spacing: SDTSpacing.xs) {
                Text("Session Complete!")
                    .sdtFont(.titleMedium)
                    .opacity(appeared ? 1 : 0)
                    .animation(SDTAnimation.scoreChange.delay(0.2), value: appeared)

                Text(durationText)
                    .sdtFont(.caption, color: .sdtSecondary)
                    .opacity(appeared ? 1 : 0)
                    .animation(SDTAnimation.scoreChange.delay(0.25), value: appeared)
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  spacing: SDTSpacing.md) {
            statCard(value: "\(summary.correctCount)/\(summary.totalChallenges)",
                     label: "Correct",
                     icon: "checkmark.circle.fill",
                     tint: .sdtHealthThriving)

            statCard(value: accuracyText,
                     label: "Accuracy",
                     icon: "percent",
                     tint: Color.sdtHealth(for: summary.accuracy))

            statCard(value: "+\(summary.xpEarned) XP",
                     label: "Earned",
                     icon: "bolt.fill",
                     tint: .sdtCategoryTool)

            statCard(value: "\(summary.skillNames.count)",
                     label: "Skills reviewed",
                     icon: "sparkles",
                     tint: .sdtCategoryProgramming)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(SDTAnimation.scoreChange.delay(0.3), value: appeared)
    }

    private func statCard(value: String, label: LocalizedStringKey, icon: String, tint: Color) -> some View {
        VStack(spacing: SDTSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tint)
            Text(value)
                .sdtFont(.titleSmall, color: tint)
            Text(label)
                .sdtFont(.caption, color: .sdtSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SDTSpacing.lg)
        .sdtCard()
    }

    // MARK: - Difficulty Adjustment Cards

    @ViewBuilder
    private var difficultyAdjustmentsSection: some View {
        let pending = summary.adjustments.filter { !resolvedAdjustments.contains($0.id) }
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: SDTSpacing.md) {
                Text("Difficulty Suggestions")
                    .sdtFont(.captionSemibold, color: .sdtSecondary)

                ForEach(pending) { adjustment in
                    DifficultyAdjustmentCard(adjustment: adjustment) {
                        // Accept — apply change and mark resolved
                        onApplyAdjustment?(adjustment)
                        withAnimation { _ = resolvedAdjustments.insert(adjustment.id) }
                    } onDismiss: {
                        withAnimation { _ = resolvedAdjustments.insert(adjustment.id) }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(SDTAnimation.scoreChange.delay(0.35), value: appeared)
        }
    }

    // MARK: - Skills Reviewed

    @ViewBuilder
    private var skillsReviewed: some View {
        if !summary.skillNames.isEmpty {
            VStack(alignment: .leading, spacing: SDTSpacing.md) {
                Text("Skills Reviewed")
                    .sdtFont(.captionSemibold, color: .sdtSecondary)

                FlowLayout(spacing: SDTSpacing.sm) {
                    ForEach(summary.skillNames, id: \.self) { name in
                        Text(name)
                            .sdtFont(.captionSemibold)
                            .padding(.horizontal, SDTSpacing.md)
                            .padding(.vertical, SDTSpacing.xs)
                            .background(Color.sdtSurface)
                            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.chip))
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(SDTAnimation.scoreChange.delay(0.4), value: appeared)
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button("Done", action: onDone)
            .buttonStyle(SessionButtonStyle(tint: .sdtCategoryProgramming))
    }

    // MARK: - Formatted Text

    private var durationText: String {
        let s = summary.durationSeconds
        if s < 60 { return String(localized: "\(s) seconds") }
        let mins = s / 60
        let secs = s % 60
        if secs == 0 { return String(localized: "\(mins) min") }
        return String(localized: "\(mins) min \(secs) s")
    }

    private var accuracyText: String {
        "\(Int((summary.accuracy * 100).rounded()))%"
    }
}

// MARK: - DifficultyAdjustmentCard

private struct DifficultyAdjustmentCard: View {

    let adjustment: DifficultyAdjustment
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            // Header row
            HStack(spacing: SDTSpacing.sm) {
                Text(adjustment.direction == .increase ? "🎯" : "💡")
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text(adjustment.skillName)
                        .sdtFont(.bodySemibold)
                    Text(subtitleText)
                        .sdtFont(.caption, color: .sdtSecondary)
                }

                Spacer()

                // Accuracy badge
                Text(accuracyText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accuracyColor)
                    .padding(.horizontal, SDTSpacing.sm)
                    .padding(.vertical, 4)
                    .background(accuracyColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(bodyText)
                .sdtFont(.bodyMedium, color: .sdtSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons
            HStack(spacing: SDTSpacing.sm) {
                Button(action: onAccept) {
                    Text(verbatim: acceptLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                    .padding(.horizontal, SDTSpacing.lg)
                    .padding(.vertical, SDTSpacing.sm)
                    .background(adjustment.direction == .increase
                                ? Color.sdtCategoryProgramming
                                : Color.sdtHealthWilting)
                    .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))

                Button("Keep current", action: onDismiss)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.sdtSecondary)
                    .padding(.horizontal, SDTSpacing.md)
                    .padding(.vertical, SDTSpacing.sm)
                    .background(Color.sdtBackground)
                    .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button))
            }
        }
        .padding(SDTSpacing.lg)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                .strokeBorder(
                    (adjustment.direction == .increase
                     ? Color.sdtCategoryProgramming
                     : Color.sdtHealthWilting).opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Computed text

    private var subtitleText: String {
        adjustment.direction == .increase
            ? String(localized: "Nailed it — \(adjustment.challengeCount) questions")
            : String(localized: "Struggled — \(adjustment.challengeCount) questions")
    }

    private var bodyText: String {
        adjustment.direction == .increase
            ? String(localized: "You answered \(accuracyText) correctly. Ready for harder questions and a tighter review schedule?")
            : String(localized: "You answered \(accuracyText) correctly. Easier questions and more frequent short reviews can build confidence.")
    }

    private var acceptLabel: String {
        adjustment.direction == .increase ? String(localized: "Increase difficulty") : String(localized: "Decrease difficulty")
    }

    private var accuracyText: String {
        "\(Int((adjustment.sessionAccuracy * 100).rounded()))%"
    }

    private var accuracyColor: Color {
        adjustment.direction == .increase ? Color.sdtHealthThriving : Color.sdtHealthCritical
    }
}

// MARK: - Flow Layout

/// A simple left-aligned, wrapping HStack for chips/tags.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    SessionCompleteView(
        summary: SessionSummary(
            totalChallenges: 7,
            correctCount: 5,
            xpEarned: 120,
            skillNames: ["Swift", "SwiftUI", "Git"],
            durationSeconds: 390,
            adjustments: [
                DifficultyAdjustment(skillID: UUID(), skillName: "SwiftUI",
                                     direction: .increase, sessionAccuracy: 0.95, challengeCount: 4),
                DifficultyAdjustment(skillID: UUID(), skillName: "Git",
                                     direction: .decrease, sessionAccuracy: 0.25, challengeCount: 3),
            ]
        ),
        onApplyAdjustment: { _ in },
        onDone: {}
    )
}
