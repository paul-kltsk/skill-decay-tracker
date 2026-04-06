import SwiftUI

/// Full-screen interactive constellation canvas showing all skills as star nodes.
///
/// Skills are grouped by category into cluster regions. Node size reflects
/// `peakScore` (importance). Ring colour reflects `healthScore` (current health).
///
/// Supports:
/// - **Pinch to zoom** (`MagnificationGesture`)
/// - **Drag to pan** (`DragGesture`)
/// - **Tap a node** to open the skill detail sheet
struct ConstellationView: View {

    let skills: [Skill]
    let viewModel: SkillMapViewModel

    @Environment(SubscriptionService.self) private var sub
    /// All skills (unfiltered) — needed to compute the free-tier set correctly.
    /// Passed from SkillMapView which already owns the @Query.
    let allSkills: [Skill]

    // MARK: - Gesture State

    @State private var magnifyBy: CGFloat = 1.0
    @State private var commitScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var commitOffset: CGSize = .zero
    @State private var appeared = false

    private var totalScale: CGFloat  { commitScale * magnifyBy }
    private var totalOffset: CGSize  {
        CGSize(
            width:  commitOffset.width  + dragOffset.width,
            height: commitOffset.height + dragOffset.height
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                starBackground(size: geo.size)
                connectionLines(size: geo.size)

                ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                    let locked = sub.isSkillLocked(skill, allSkills: allSkills)
                    SkillNode(skill: skill, isLocked: locked, onTap: { viewModel.select(skill) })
                        .position(viewModel.nodePosition(for: skill, in: geo.size))
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.1)
                        .animation(
                            .spring(duration: 0.5, bounce: 0.3)
                                .delay(Double(index) * 0.06),
                            value: appeared
                        )
                }
            }
            .scaleEffect(totalScale)
            .offset(totalOffset)
            .simultaneousGesture(zoomGesture)
            .simultaneousGesture(panGesture)
            .clipped()
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in magnifyBy = value }
            .onEnded { value in
                commitScale = min(3.0, max(0.4, commitScale * value))
                magnifyBy = 1.0
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in dragOffset = value.translation }
            .onEnded { value in
                commitOffset.width  += value.translation.width
                commitOffset.height += value.translation.height
                dragOffset = .zero
            }
    }

    // MARK: - Star Background

    private func starBackground(size: CGSize) -> some View {
        Canvas { ctx, _ in
            let primesX = [17, 31, 43, 53, 67, 79, 97, 101, 113, 127]
            let primesY = [13, 23, 37, 47, 61, 71, 89, 103, 107, 109]

            for i in 0..<70 {
                let x       = CGFloat((i * primesX[i % primesX.count]) % 100) / 100.0 * size.width
                let y       = CGFloat((i * primesY[i % primesY.count] + 7) % 100) / 100.0 * size.height
                let opacity = Double((i * 7 + 3) % 10) / 35.0 + 0.04
                let r: CGFloat = (i % 6 == 0) ? 1.5 : 1.0

                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(Color.sdtSecondary.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Connection Lines

    /// Dashed lines connecting skills within the same category.
    /// Positions are pre-computed outside Canvas to avoid SwiftData access in the drawing closure.
    private func connectionLines(size: CGSize) -> some View {
        let lineData: [(color: Color, points: [CGPoint])] = SkillCategory.allCases.compactMap { category in
            let pts = skills
                .filter { $0.category == category }
                .map { viewModel.nodePosition(for: $0, in: size) }
            guard pts.count > 1 else { return nil }
            return (color: category.color, points: pts)
        }

        return Canvas { ctx, _ in
            for line in lineData {
                var path = Path()
                path.move(to: line.points[0])
                for pt in line.points.dropFirst() {
                    path.addLine(to: pt)
                }
                ctx.stroke(
                    path,
                    with: .color(line.color.opacity(0.22)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 7])
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - SkillNode

/// Individual skill node displayed on the constellation canvas.
private struct SkillNode: View {

    let skill: Skill
    let isLocked: Bool
    let onTap: () -> Void

    @State private var glowPulse = false

    private var nodeRadius: CGFloat { 16 + CGFloat(skill.peakScore) * 12 }
    private var isHealthy: Bool     { skill.healthScore >= 0.7 }

    var body: some View {
        Button(action: { if !isLocked { onTap() } }) {
            VStack(spacing: 5) {
                ZStack {
                    // Glow halo — suppressed for locked nodes
                    if isHealthy && !isLocked {
                        Circle()
                            .fill(
                                Color.sdtHealth(for: skill.healthScore)
                                    .opacity(glowPulse ? 0.35 : 0.12)
                            )
                            .frame(width: nodeRadius * 3.2, height: nodeRadius * 3.2)
                            .blur(radius: 10)
                    }

                    // Category tint background
                    Circle()
                        .fill(skill.category.color.opacity(isLocked ? 0.06 : 0.18))
                        .frame(width: nodeRadius * 2, height: nodeRadius * 2)

                    // Health ring overlay
                    SDTHealthRing(score: skill.healthScore, lineWidth: 2.5)
                        .frame(width: nodeRadius * 2 + 6, height: nodeRadius * 2 + 6)

                    // Category symbol (hidden by lock icon when locked)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: nodeRadius * 0.55, weight: .medium))
                            .foregroundStyle(Color.sdtSecondary)
                    } else {
                        Image(systemName: skill.category.systemImage)
                            .font(.system(size: nodeRadius * 0.65, weight: .medium))
                            .foregroundStyle(skill.category.color)
                    }
                }

                Text(skill.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isLocked ? Color.sdtSecondary : Color.sdtPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 76)
            }
        }
        .buttonStyle(.plain)
        .grayscale(isLocked ? 0.9 : 0)
        .opacity(isLocked ? 0.5 : 1)
        .onAppear {
            if isHealthy && !isLocked {
                withAnimation(SDTAnimation.healthyPulse) { glowPulse = true }
            }
        }
    }
}
