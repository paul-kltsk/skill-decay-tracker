import SwiftUI

/// Shown when all challenges in a session are answered.
///
/// Displays accuracy, XP earned, skills reviewed, and session duration.
struct SessionCompleteView: View {

    let summary: SessionSummary
    let onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SDTSpacing.xl) {
                    header
                    statsGrid
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

    private func statCard(value: String, label: String, icon: String, tint: Color) -> some View {
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
        if s < 60 { return "\(s) seconds" }
        let mins = s / 60
        let secs = s % 60
        return secs == 0 ? "\(mins) min" : "\(mins) min \(secs) s"
    }

    private var accuracyText: String {
        "\(Int((summary.accuracy * 100).rounded()))%"
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
            durationSeconds: 390
        )
    ) {}
}
