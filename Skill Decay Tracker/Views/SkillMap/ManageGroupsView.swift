import SwiftUI
import SwiftData

// MARK: - ManageGroupsView

/// Sheet for creating, renaming, and deleting skill groups.
///
/// - Swipe-to-delete a group → skills in that group become ungrouped.
/// - Tap a group name to rename it inline.
/// - Tap "New Group" to create one with a name and emoji.
struct ManageGroupsView: View {

    @Query(sort: \SkillGroup.name) private var groups: [SkillGroup]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateSheet = false
    @State private var editingGroup: SkillGroup? = nil
    @State private var editName = ""
    @State private var editEmoji = ""

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    emptyState
                } else {
                    ForEach(groups) { group in
                        groupRow(group)
                    }
                    .onDelete(perform: deleteGroups)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.sdtBackground)
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateGroupView()
            }
            .sheet(item: $editingGroup) { group in
                RenameGroupView(group: group)
            }
        }
    }

    // MARK: - Group Row

    private func groupRow(_ group: SkillGroup) -> some View {
        HStack(spacing: SDTSpacing.md) {
            Text(group.emoji)
                .font(.system(size: 24))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .sdtFont(.bodySemibold)
                Text(skillCountLabel(group))
                    .sdtFont(.caption, color: .sdtSecondary)
            }

            Spacer()

            Button {
                editingGroup = group
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(Color.sdtSecondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, SDTSpacing.xs)
        .listRowBackground(Color.sdtSurface)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SDTSpacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(Color.sdtSecondary)
            Text("No groups yet")
                .sdtFont(.bodySemibold)
            Text("Tap + to create your first group and organise your skills.")
                .sdtFont(.bodyMedium, color: .sdtSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SDTSpacing.xxxl)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Delete

    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            let group = groups[index]
            // Nullify relationship on all skills first
            for skill in group.skills {
                skill.group = nil
            }
            modelContext.delete(group)
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func skillCountLabel(_ group: SkillGroup) -> String {
        let count = group.skills.count
        return count == 1 ? "1 skill" : "\(count) skills"
    }
}

// MARK: - CreateGroupView

struct CreateGroupView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "📁"
    @FocusState private var nameFocused: Bool

    private let suggestedEmojis = [
        "📁", "💻", "🧠", "📚", "🎨", "🔧", "🌍", "🎯",
        "⚡️", "🏋️", "🎵", "🔬", "📊", "🚀", "🌱", "💡",
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Emoji picker
                Section("Icon") {
                    VStack(alignment: .leading, spacing: SDTSpacing.md) {
                        // Selected emoji preview
                        HStack {
                            Spacer()
                            Text(emoji)
                                .font(.system(size: 56))
                            Spacer()
                        }
                        .padding(.top, SDTSpacing.sm)

                        // Quick picks
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 8),
                            spacing: SDTSpacing.sm
                        ) {
                            ForEach(suggestedEmojis, id: \.self) { e in
                                Button {
                                    emoji = e
                                } label: {
                                    Text(e)
                                        .font(.system(size: 26))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            emoji == e
                                                ? Color.sdtPrimary.opacity(0.15)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, SDTSpacing.xs)
                    }
                    .listRowBackground(Color.sdtSurface)
                }

                // Name
                Section("Group Name") {
                    TextField("e.g. Swift, Design, Languages…", text: $name)
                        .focused($nameFocused)
                        .listRowBackground(Color.sdtSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.sdtBackground)
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createGroup() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private func createGroup() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let group = SkillGroup(name: trimmed, emoji: emoji)
        modelContext.insert(group)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - RenameGroupView

struct RenameGroupView: View {

    let group: SkillGroup

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = ""
    @FocusState private var nameFocused: Bool

    private let suggestedEmojis = [
        "📁", "💻", "🧠", "📚", "🎨", "🔧", "🌍", "🎯",
        "⚡️", "🏋️", "🎵", "🔬", "📊", "🚀", "🌱", "💡",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Icon") {
                    VStack(alignment: .leading, spacing: SDTSpacing.md) {
                        HStack {
                            Spacer()
                            Text(emoji)
                                .font(.system(size: 56))
                            Spacer()
                        }
                        .padding(.top, SDTSpacing.sm)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 8),
                            spacing: SDTSpacing.sm
                        ) {
                            ForEach(suggestedEmojis, id: \.self) { e in
                                Button {
                                    emoji = e
                                } label: {
                                    Text(e)
                                        .font(.system(size: 26))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            emoji == e
                                                ? Color.sdtPrimary.opacity(0.15)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, SDTSpacing.xs)
                    }
                    .listRowBackground(Color.sdtSurface)
                }

                Section("Group Name") {
                    TextField("Group name", text: $name)
                        .focused($nameFocused)
                        .listRowBackground(Color.sdtSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.sdtBackground)
            .navigationTitle("Rename Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = group.name
                emoji = group.emoji
                nameFocused = true
            }
        }
    }

    private func save() {
        group.name = name.trimmingCharacters(in: .whitespaces)
        group.emoji = emoji
        try? modelContext.save()
        dismiss()
    }
}
