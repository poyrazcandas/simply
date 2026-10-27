import SwiftUI

struct HabitManagerView: View {
    @EnvironmentObject private var store: TrackerStore
    @State private var newTitle = ""
    @State private var newCategory: HabitCategory = .morning
    @State private var editingId: String?
    @State private var editTitle = ""
    @State private var editCategory: HabitCategory = .morning
    @State private var draggingId: String?

    private var grouped: [HabitCategory: [Habit]] {
        Categories.groupHabitsByCategory(store.habits)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings")
                    .font(.stoic( 11, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.primary.opacity(0.75))
                Text("Habit Manager")
                    .font(.stoic( 32, weight: .semibold))
                Text("Add, edit, or remove habits. Deleted habits stay in past logs safely.")
                    .font(.title3)
                    .foregroundStyle(AppTheme.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .chromeCard()

            addCard
            listCard
        }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add New Habit")
                .font(.title3.weight(.semibold))
            Text("Choose a name and which part of your day it belongs to")
                .foregroundStyle(AppTheme.mutedText)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Habit Name").font(.subheadline.weight(.medium))
                    TextField("e.g. Morning meditation", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time block").font(.subheadline.weight(.medium))
                    Picker("", selection: $newCategory) {
                        ForEach(Categories.order) { cat in
                            Text(Categories.labels[cat] ?? cat.rawValue).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                Button(action: add) {
                    Label("Add habit", systemImage: "plus")
                        .font(.stoic( 15, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(AppTheme.primary.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.primary.opacity(0.5), lineWidth: 2))
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)
            .background(AppTheme.muted.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
        .chromeCard(accent: AppTheme.primary)
    }

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Habits")
                .font(.title3.weight(.semibold))
            Text(
                store.habits.isEmpty
                    ? "Four time blocks below. Add habits above, then drag between blocks to organize."
                    : "\(store.habits.count) active habit\(store.habits.count == 1 ? "" : "s"). Drag to reorder or move between blocks."
            )
            .foregroundStyle(AppTheme.mutedText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Categories.order) { cat in
                    categoryColumn(cat, habits: grouped[cat] ?? [])
                }
            }
        }
        .chromeCard()
    }

    private func categoryColumn(_ category: HabitCategory, habits: [Habit]) -> some View {
        let accent = AppTheme.blockAccent(category)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(Categories.labels[category] ?? "", systemImage: icon(for: category))
                    .font(.headline)
                Spacer()
                Text("\(habits.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.mutedText)
            }
            if habits.isEmpty {
                Text(Categories.emptyMessages[category] ?? "")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(draggingId == nil ? AppTheme.border : AppTheme.primary)
                    )
                    .dropDestination(for: String.self) { items, _ in
                        guard let id = items.first else { return false }
                        store.moveHabit(activeId: id, targetCategory: category, overId: nil)
                        draggingId = nil
                        return true
                    }
            } else {
                VStack(spacing: 8) {
                    ForEach(habits) { habit in
                        habitRow(habit, in: category)
                    }
                }
            }
        }
        .timeBlockCard(accent)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            store.moveHabit(activeId: id, targetCategory: category, overId: nil)
            draggingId = nil
            return true
        }
    }

    private func habitRow(_ habit: Habit, in category: HabitCategory) -> some View {
        Group {
            if editingId == habit.id {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: $editTitle)
                        .textFieldStyle(.roundedBorder)
                    Picker("Block", selection: $editCategory) {
                        ForEach(Categories.order) { cat in
                            Text(Categories.labels[cat] ?? cat.rawValue).tag(cat)
                        }
                    }
                    HStack {
                        Button("Save") {
                            store.updateHabit(id: habit.id, title: editTitle, category: editCategory)
                            editingId = nil
                        }
                        .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel") { editingId = nil }
                    }
                }
                .padding(10)
                .background(AppTheme.muted.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.primary.opacity(0.4), lineWidth: 2))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(AppTheme.mutedText)
                        .help("Drag to move \(habit.title)")
                    Text(habit.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Text(Categories.labels[habit.category] ?? "")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.blockAccent(habit.category).opacity(0.18), in: Capsule())
                    Button {
                        editingId = habit.id
                        editTitle = habit.title
                        editCategory = habit.category
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .help("Edit \(habit.title)")
                    Button(role: .destructive) {
                        store.deleteHabit(id: habit.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.destructive)
                    .help("Delete \(habit.title)")
                }
                .padding(8)
                .background(AppTheme.secondary, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.8), lineWidth: 1.5))
                .opacity(draggingId == habit.id ? 0.4 : 1)
                .onDrag {
                    draggingId = habit.id
                    return NSItemProvider(object: habit.id as NSString)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let id = items.first else { return false }
                    store.moveHabit(activeId: id, targetCategory: category, overId: habit.id)
                    draggingId = nil
                    return true
                }
            }
        }
    }

    private func add() {
        store.addHabit(title: newTitle, category: newCategory)
        newTitle = ""
        newCategory = .morning
    }

    private func icon(for category: HabitCategory) -> String {
        switch category {
        case .morning: return "sun.max.fill"
        case .dayActivities: return "bolt.heart.fill"
        case .dayHabits: return "arrow.triangle.2.circlepath"
        case .night: return "moon.fill"
        }
    }
}
