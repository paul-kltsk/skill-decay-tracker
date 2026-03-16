import SwiftUI
import SwiftData

/// Full-screen achievements list with XP level card and badge grid.
struct AchievementsView: View {

    @Query(sort: \Skill.healthScore) private var skills: [Skill]
    @State private var viewModel = AnalyticsViewModel()
    @State private var appeared = false

    var body: some View {
        let xp           = viewModel.totalXP(for: skills)
        let lvl          = viewModel.level(xp: xp)
        let progress     = viewModel.levelProgress(xp: xp)
        let toNext       = viewModel.xpToNext(xp: xp)
        let achievements = viewModel.achievements(for: skills)
        let unlocked     = achievements.filter { $0.isUnlocked }.count

        ScrollView {
            VStack(spacing: SDTSpacing.xxl) {
                levelCard(xp: xp, lvl: lvl, progress: progress, toNext: toNext)
                achievementGrid(achievements: achievements, unlocked: unlocked)
            }
            .padding(.horizontal, SDTSpacing.xl)
            .padding(.vertical, SDTSpacing.lg)
        }
        .background(Color.sdtBackground)
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(SDTAnimation.scoreChange) { appeared = true }
        }
    }

    // MARK: - Level Card

    private func levelCard(xp: Int, lvl: Int, progress: Double, toNext: Int) -> some View {
        VStack(spacing: SDTSpacing.lg) {
            // Level ring
            ZStack {
                Circle()
                    .stroke(Color.sdtSecondary.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: appeared ? progress : 0)
                    .stroke(
                        AngularGradient(
                            colors: [Color.sdtCategoryProgramming, Color.sdtCategoryLanguage],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(SDTAnimation.scoreChange, value: appeared)

                VStack(spacing: 2) {
                    Text("LV")
                        .sdtFont(.captionSemibold, color: .sdtSecondary)
                    Text("\(lvl)")
                        .sdtFont(.numericLarge, color: .sdtCategoryProgramming)
                }
            }
            .frame(width: 110, height: 110)

            VStack(spacing: SDTSpacing.xs) {
                Text("\(xp) XP total")
                    .sdtFont(.titleSmall)
                Text("\(toNext) XP to Level \(lvl + 1)")
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
            }

            SDTProgressBar(value: progress)
                .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .sdtCard()
    }

    // MARK: - Achievement Grid

    private func achievementGrid(achievements: [Achievement], unlocked: Int) -> some View {
        VStack(alignment: .leading, spacing: SDTSpacing.md) {
            HStack {
                Text("Badges")
                    .sdtFont(.bodySemibold)
                Spacer()
                Text("\(unlocked) / \(achievements.count)")
                    .sdtFont(.captionSemibold, color: .sdtSecondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: SDTSpacing.md
            ) {
                ForEach(achievements) { a in
                    AchievementCard(achievement: a)
                }
            }
        }
    }
}

// MARK: - AchievementCard

private struct AchievementCard: View {
    let achievement: Achievement
    @State private var appeared = false

    var body: some View {
        HStack(spacing: SDTSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                            ? Color.sdtCategoryProgramming.opacity(0.15)
                            : Color.sdtSecondary.opacity(0.08)
                    )
                    .frame(width: 48, height: 48)

                // Progress ring (only when not yet unlocked)
                if !achievement.isUnlocked {
                    Circle()
                        .trim(from: 0, to: achievement.progress)
                        .stroke(
                            Color.sdtCategoryProgramming.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 48, height: 48)
                }

                Image(systemName: achievement.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        achievement.isUnlocked
                            ? Color.sdtCategoryProgramming
                            : Color.sdtSecondary.opacity(0.35)
                    )
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(
                        .spring(duration: 0.4, bounce: 0.3).delay(0.1),
                        value: appeared
                    )
            }

            // Text
            VStack(alignment: .leading, spacing: SDTSpacing.xxs) {
                Text(achievement.title)
                    .sdtFont(.captionSemibold,
                             color: achievement.isUnlocked ? .sdtPrimary : .sdtSecondary)
                Text(achievement.description)
                    .sdtFont(.caption, color: .sdtSecondary)
                    .lineLimit(2)

                if !achievement.isUnlocked {
                    SDTProgressBar(value: achievement.progress)
                        .frame(height: 3)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(SDTSpacing.md)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                .strokeBorder(
                    achievement.isUnlocked
                        ? Color.sdtCategoryProgramming.opacity(0.35)
                        : Color.clear,
                    lineWidth: 1
                )
        )
        .onAppear { appeared = true }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { AchievementsView() }
}
