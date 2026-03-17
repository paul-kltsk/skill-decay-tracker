import Foundation
import SwiftData

// MARK: - SkillGroup

/// A user-created group that organises related skills together.
///
/// Skills reference their group via the optional `Skill.group` relationship.
/// Deleting a group does **not** delete the skills — they become ungrouped
/// (`skill.group == nil`) via the `.nullify` delete rule.
///
/// **Example:**
/// ```
/// Group "Swift"  →  [Combine, GCD, async/await]
/// Group "Design" →  [Figma, Color Theory]
/// (ungrouped)    →  [Spanish, SQL]
/// ```
@Model
final class SkillGroup {

    // MARK: Identity

    var id: UUID
    var name: String
    /// A single emoji that acts as the group's visual icon.
    var emoji: String
    var createdAt: Date

    // MARK: Relationship

    /// Skills that belong to this group.
    ///
    /// Delete rule `.nullify` — removing the group leaves skills intact
    /// but sets their `group` pointer to `nil`.
    @Relationship(deleteRule: .nullify, inverse: \Skill.group)
    var skills: [Skill]

    // MARK: Init

    init(name: String, emoji: String = "📁") {
        self.id        = UUID()
        self.name      = name
        self.emoji     = emoji
        self.createdAt = Date.now
        self.skills    = []
    }
}
