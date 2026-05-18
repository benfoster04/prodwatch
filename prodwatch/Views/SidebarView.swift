import SwiftUI

// MARK: - SidebarView
/// Displays the show structure — acts and sections — and allows editing.
struct SidebarView: View {
    @ObservedObject var engine: TimerEngine
    @Binding var show: Show

    @State private var editingShow = false
    @State private var addingActName = ""
    @State private var showAddAct = false

    var body: some View {
        VStack(spacing: 0) {
            // Show header
            showHeader

            Divider()

            // Acts + Sections list
            List {
                ForEach($show.acts) { $act in
                    ActSectionView(
                        act: $act,
                        engine: engine,
                        onDelete: { deleteAct(act) }
                    )
                }
                .onMove(perform: moveAct)
            }
            .listStyle(.sidebar)

            Divider()

            // Add Act button
            addActFooter
        }
    }

    // MARK: - Subviews

    private var showHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(show.title)
                        .font(.headline)
                        .lineLimit(1)
                    if !show.venue.isEmpty {
                        Text(show.venue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(show.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    editingShow = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .sheet(isPresented: $editingShow) {
            ShowEditView(show: $show)
        }
    }

    private var addActFooter: some View {
        HStack {
            if showAddAct {
                TextField("Section name", text: $addingActName)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .onSubmit { commitAddAct() }
                Button("Add", action: commitAddAct)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Cancel") {
                    showAddAct = false
                    addingActName = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Button {
                    showAddAct = true
                } label: {
                    Label("Add Section", systemImage: "plus.circle")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }

    // MARK: - Actions
    @AppStorage("autoCreateTimer")  private var autoCreateTimer: Bool = true

    private func commitAddAct() {
        let name = addingActName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var act = Act(name: name)
        if (autoCreateTimer) {
            act.sections.append(ShowSection(
                name: name,
                sectionType: SectionType.primary
            ))
        }
        show.acts.append(act)
        addingActName = ""
        showAddAct = false
    }

    private func deleteAct(_ act: Act) {
        show.acts.removeAll { $0.id == act.id }
    }

    private func moveAct(from source: IndexSet, to destination: Int) {
        show.acts.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - ActSectionView
/// A single section row with its expandable list of stopwatches.
struct ActSectionView: View {
    @Binding var act: Act
    @ObservedObject var engine: TimerEngine
    let onDelete: () -> Void

    @State private var isExpanded = true
    @State private var editingActName = false
    @State private var addingSectionName = ""
    @State private var showAddSection = false

    var body: some View {
        Section(isExpanded: $isExpanded) {
            ForEach($act.sections) { $section in
                SectionRowView(
                    section: $section,
                    isActive: isActive(section),
                    onDelete: { deleteSection(section) }
                )
            }
            .onMove(perform: moveSection)

            // Add section inline
            if showAddSection {
                HStack {
                    TextField("Stopwatch name", text: $addingSectionName)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .onSubmit { commitAddSection() }
                    Button("Add", action: commitAddSection)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Cancel") {
                        showAddSection = false
                        addingSectionName = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.leading, 8)
            } else {
                Button {
                    showAddSection = true
                } label: {
                    Label("Add Stopwatch", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        } header: {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .onTapGesture { isExpanded.toggle() }

                if editingActName {
                    TextField("Section name", text: $act.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .onSubmit { editingActName = false }
                } else {
                    Text(act.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Menu {
                    Button("Rename") { editingActName = true }
                    Divider()
                    Button("Delete Section", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.vertical, 4)
        }
    }

    private func isActive(_ section: ShowSection) -> Bool {
        guard let run = engine.showRun else { return false }
        let acts = run.show.acts
        guard engine.currentActIndex < acts.count else { return false }
        let sections = acts[engine.currentActIndex].sections
        guard engine.currentSectionIndex < sections.count else { return false }
        return sections[engine.currentSectionIndex].id == section.id &&
               acts[engine.currentActIndex].id == act.id
    }

    private func commitAddSection() {
        let name = addingSectionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        act.sections.append(ShowSection(name: name))
        addingSectionName = ""
        showAddSection = false
    }

    private func deleteSection(_ section: ShowSection) {
        act.sections.removeAll { $0.id == section.id }
    }

    private func moveSection(from source: IndexSet, to destination: Int) {
        act.sections.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - SectionRowView
/// A single section row with active highlight and edit/delete controls.
struct SectionRowView: View {
    @Binding var section: ShowSection
    let isActive: Bool
    let onDelete: () -> Void

    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            // Active indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.name)
                    .font(.callout)
                    .foregroundStyle(isActive ? .primary : .secondary)

                HStack(spacing: 6) {
                    // Section type badge
                    Text(section.sectionType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(typeColor(section.sectionType).opacity(0.15))
                        .foregroundStyle(typeColor(section.sectionType))
                        .clipShape(Capsule())

                    // Target duration
                    if let target = section.targetDuration {
                        Text(target.shortFormatted)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Menu {
                Button("Edit") { isEditing = true }
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .sheet(isPresented: $isEditing) {
            SectionEditView(section: $section)
        }
    }

    private func typeColor(_ type: SectionType) -> Color {
        switch type {
        case .primary:   return .blue
        case .timestamp: return .purple
        }
    }
}

// MARK: - ShowEditView
/// Sheet for editing show-level metadata.
struct ShowEditView: View {
    @Binding var show: Show
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Show")
                .font(.title2).bold()

            LabeledContent("Title") {
                TextField("Show title", text: $show.title)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Venue") {
                TextField("Venue", text: $show.venue)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Date") {
                DatePicker("", selection: $show.date, displayedComponents: .date)
                    .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

// MARK: - SectionEditView
/// Sheet for editing a section's name, type, target duration, and notes.
struct SectionEditView: View {
    @Binding var section: ShowSection
    @Environment(\.dismiss) var dismiss

    @State private var targetMinutes: String = ""
    @State private var targetSeconds: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Stopwatch")
                .font(.title2).bold()

            LabeledContent("Name") {
                TextField("Stopwatch name", text: $section.name)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Type") {
                Picker("", selection: $section.sectionType) {
                    ForEach(SectionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            LabeledContent("Target Duration") {
                HStack(spacing: 6) {
                    TextField("MM", text: $targetMinutes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text(":")
                    TextField("SS", text: $targetSeconds)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Button("Clear") {
                        section.targetDuration = nil
                        targetMinutes = ""
                        targetSeconds = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }

            LabeledContent("Notes") {
                TextField("Notes", text: $section.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Done") {
                    commitTarget()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear { loadTarget() }
    }

    private func loadTarget() {
        guard let t = section.targetDuration else { return }
        let total = Int(t)
        targetMinutes = String(total / 60)
        targetSeconds = String(format: "%02d", total % 60)
    }

    private func commitTarget() {
        let m = Int(targetMinutes) ?? 0
        let s = Int(targetSeconds) ?? 0
        let total = m * 60 + s
        section.targetDuration = total > 0 ? TimeInterval(total) : nil
    }
}
