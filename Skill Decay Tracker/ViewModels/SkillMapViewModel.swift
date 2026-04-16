import SwiftUI
import SwiftData

// MARK: - Map View Mode

enum MapViewMode: String, CaseIterable {
    case constellation = "Constellation"
    case grid          = "Grid"

    var systemImage: String {
        switch self {
        case .constellation: "sparkles"
        case .grid:          "square.grid.2x2"
        }
    }

    var displayName: String {
        switch self {
        case .constellation: String(localized: "Constellation")
        case .grid:          String(localized: "Grid")
        }
    }
}

// MARK: - Sort Order

enum SkillSortOrder: String, CaseIterable {
    case health        = "Health"
    case name          = "Name"
    case lastPracticed = "Recent"
    case streak        = "Streak"

    var systemImage: String {
        switch self {
        case .health:        "heart"
        case .name:          "textformat.abc"
        case .lastPracticed: "clock"
        case .streak:        "flame"
        }
    }

    var displayName: String {
        switch self {
        case .health:        String(localized: "Health")
        case .name:          String(localized: "Name")
        case .lastPracticed: String(localized: "Recent")
        case .streak:        String(localized: "Streak")
        }
    }
}

// MARK: - SkillMapViewModel

/// ViewModel for ``SkillMapView``.
///
/// Owns all presentation-layer state: view mode toggle, filter/sort settings,
/// skill-detail sheet, and the deterministic constellation node-position logic.
///
/// Reactive skill data comes from `@Query` in the view;
/// computed filtering/sorting is applied here by accepting the `[Skill]` array.
@Observable
@MainActor
final class SkillMapViewModel {

    // MARK: - UI State

    var viewMode: MapViewMode = .grid
    var selectedCategory: SkillCategory? = nil
    var sortOrder: SkillSortOrder = .health
    var selectedSkill: Skill? = nil
    var showDetail = false
    var showAddSkill = false

    // MARK: - Filtering & Sorting

    /// Returns a filtered and sorted copy of `skills`.
    func filtered(_ skills: [Skill]) -> [Skill] {
        var result = skills
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        return sorted(result)
    }

    private func sorted(_ skills: [Skill]) -> [Skill] {
        switch sortOrder {
        case .health:
            return skills.sorted { $0.healthScore < $1.healthScore }
        case .name:
            return skills.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .lastPracticed:
            return skills.sorted { $0.lastPracticed > $1.lastPracticed }
        case .streak:
            return skills.sorted { $0.streakDays > $1.streakDays }
        }
    }

    // MARK: - Selection

    func select(_ skill: Skill) {
        selectedSkill = skill
        showDetail = true
    }

    // MARK: - Health Refresh

    func refreshHealth(for skills: [Skill]) {
        skills.forEach { DecayEngine.refreshHealth(for: $0) }
    }

    // MARK: - Constellation Node Positions

    /// Returns a deterministic `CGPoint` for a skill node on the constellation canvas.
    ///
    /// Skills cluster near their category's anchor, with a stable per-skill offset
    /// derived from the first two bytes of the skill's UUID.
    func nodePosition(for skill: Skill, in size: CGSize) -> CGPoint {
        let anchor = categoryAnchor(for: skill.category)
        let offset = deterministicOffset(from: skill.id)
        return CGPoint(
            x: (anchor.x + offset.x) * size.width,
            y: (anchor.y + offset.y) * size.height
        )
    }

    private func categoryAnchor(for category: SkillCategory) -> CGPoint {
        switch category {
        case .programming: CGPoint(x: 0.28, y: 0.26)
        case .language:    CGPoint(x: 0.72, y: 0.21)
        case .tool:        CGPoint(x: 0.17, y: 0.63)
        case .concept:     CGPoint(x: 0.76, y: 0.68)
        case .custom:      CGPoint(x: 0.50, y: 0.47)
        }
    }

    private func deterministicOffset(from id: UUID) -> CGPoint {
        withUnsafeBytes(of: id.uuid) { bytes in
            let dx = (Double(bytes[0]) / 255.0 - 0.5) * 0.22
            let dy = (Double(bytes[1]) / 255.0 - 0.5) * 0.22
            return CGPoint(x: dx, y: dy)
        }
    }
}
