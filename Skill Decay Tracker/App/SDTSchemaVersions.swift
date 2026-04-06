import SwiftData

// MARK: - Schema V1
//
// Snapshot of the original schema (CloudKit-disabled, non-optional relationships).
// Captured here so SwiftData can perform a lightweight V1 → V2 migration on
// existing stores. Models in this enum still reference the current @Model types;
// SwiftData reads the version stored in the SQLite metadata to determine which
// migration stages to apply.

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Skill.self, Challenge.self, ChallengeResult.self, UserProfile.self, SkillGroup.self]
    }
}

// MARK: - Schema V2
//
// CloudKit-compatible schema:
// • All stored properties have default values or are optional
// • All @Relationship arrays are [T]? (required by CloudKit)

enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Skill.self, Challenge.self, ChallengeResult.self, UserProfile.self, SkillGroup.self]
    }
}

// MARK: - Schema V3
//
// Adds `Skill.questionCount: Int = 5` — the per-skill session length chosen during creation.
// Lightweight migration: adding a column with a default requires no data transformation.

enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Skill.self, Challenge.self, ChallengeResult.self, UserProfile.self, SkillGroup.self]
    }
}

// MARK: - Migration Plan

/// Lightweight V1 → V2 → V3 migration.
///
/// SwiftData handles this automatically: relaxing array optionality, adding property defaults,
/// and adding new columns with defaults do not alter the SQLite table structure in a breaking way.
enum SDTMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self] }
    static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            MigrationStage.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        ]
    }
}
