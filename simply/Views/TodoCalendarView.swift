import SwiftUI
import UniformTypeIdentifiers

struct TodoCalendarView: View {
    @EnvironmentObject private var store: TrackerStore
    @State private var mode: Mode = .todo

    enum Mode { case todo, calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.title2)
                        .foregroundStyle(AppTheme.palette(.violet))
                        .frame(width: 40, height: 40)
                        .background(AppTheme.palette(.violet).opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.palette(.violet).opacity(0.4)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plans & schedule")
                            .font(.caption.weight(.medium))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.palette(.violet).opacity(0.9))
                        Text("To-Do/Calendar")
                            .font(.stoic( 22, weight: .semibold))
                    }
                }
                Spacer()
                HStack(spacing: 0) {
                    modeButton("To-Do", .todo, "checklist")
                    modeButton("Calendar", .calendar, "calendar")
                }
                .padding(4)
                .background(AppTheme.muted.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(14)
            .background(
                LinearGradient(colors: [AppTheme.palette(.violet).opacity(0.18), AppTheme.card], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.palette(.violet).opacity(0.4), lineWidth: 2))

            Group {
                if mode == .todo {
                    TodoListView(navigateTo: store.todoNavigateDateKey)
                } else {
                    PlannerCalendarView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func modeButton(_ title: String, _ value: Mode, _ image: String) -> some View {
        Button {
            mode = value
        } label: {
            Label(title, systemImage: image)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(mode == value ? AppTheme.primary : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(mode == value ? Color.white : AppTheme.mutedText)
        }
        .buttonStyle(.plain)
    }
}

struct TodoListView: View {
    @EnvironmentObject private var store: TrackerStore
    var navigateTo: String?

    @State private var viewDate: String = DateKeys.formatDateKey(Date())
    @State private var monthCursor: Date = Date()
    @State private var title = ""
    @State private var scope: TodoScope = .day
    @State private var startTime = "09:00"
    @State private var endTime = "10:00"
    @State private var weekMode: WeekDueMode = .weekEndSunday
    @State private var monthMode: MonthDueMode = .calendarMonthEnd
    @State private var selectedTagIds: Set<String> = []
    @State private var editing: TodoItem?
    @State private var newTagName = ""
    @State private var newTagColor: PaletteColor = .violet

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            monthPane
            listPane
        }
        .onAppear {
            viewDate = navigateTo ?? store.todayKey
            monthCursor = DateKeys.parseDateKey(viewDate)
        }
        .onChange(of: navigateTo) { _, new in
            if let new {
                viewDate = new
                monthCursor = DateKeys.parseDateKey(new)
            }
        }
    }

    private var monthPane: some View {
        let days = CalendarDisplay.getMonthGridDays(
            year: Calendar.current.component(.year, from: monthCursor),
            month: Calendar.current.component(.month, from: monthCursor)
        )
        let timedDates = Todos.getTimedEventDateKeys(store.todos)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { monthCursor = Calendar.current.date(byAdding: .month, value: -1, to: monthCursor) ?? monthCursor } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthCursor.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button { monthCursor = Calendar.current.date(byAdding: .month, value: 1, to: monthCursor) ?? monthCursor } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(CalendarDisplay.weekdayHeaders, id: \.self) { h in
                    Text(h).font(.caption2.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                }
                ForEach(days, id: \.self) { key in
                    let inMonth = key.prefix(7) == DateKeys.formatDateKey(monthCursor).prefix(7)
                    let indicators = TodoTags.getTagIndicatorsForDate(dateKey: key, todos: store.todos, catalog: store.todoTags)
                    Button {
                        viewDate = key
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(Calendar.current.component(.day, from: DateKeys.parseDateKey(key)))")
                                .font(.stoic( 12, weight: key == store.todayKey ? .bold : .medium))
                                .foregroundStyle(key == viewDate ? .white : (inMonth ? AppTheme.text : AppTheme.mutedText.opacity(0.45)))
                            HStack(spacing: 2) {
                                ForEach(indicators.colors, id: \.self) { color in
                                    Circle().fill(AppTheme.palette(color)).frame(width: 5, height: 5)
                                }
                                if indicators.overflow > 0 {
                                    Text("+\(indicators.overflow)").font(.stoic( 7)).foregroundStyle(AppTheme.mutedText)
                                }
                            }
                            .frame(height: 7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(key == viewDate ? AppTheme.primary : (timedDates.contains(key) ? AppTheme.palette(.violet).opacity(0.12) : Color.clear))
                        )
                        .overlay(
                            Circle()
                                .stroke(key == store.todayKey ? Color.red : Color.clear, lineWidth: 2)
                                .frame(width: 22, height: 22)
                                .offset(y: -8)
                                .opacity(key == store.todayKey && key != viewDate ? 1 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .chromeCard()
    }

    private var listPane: some View {
        let grouped = Todos.groupTodosForDate(store.todos, viewDateKey: viewDate, todayKey: store.todayKey)
        return VStack(alignment: .leading, spacing: 12) {
            Text(DateKeys.formatDisplayDate(viewDate, today: store.todayKey))
                .font(.title2.weight(.semibold))
            addForm
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    column("Timed", grouped.timed, .timed)
                    column("This day", grouped.day, .day)
                    column("This week", grouped.week, .week)
                    column("This month", grouped.month, .month)
                    if viewDate == store.todayKey, !grouped.pastDue.isEmpty {
                        column("Past due", grouped.pastDue, nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { todo in
            TodoEditorSheet(todo: todo, tags: store.todoTags) { updated, delete in
                if delete {
                    store.saveTodos(store.todos.filter { $0.id != todo.id })
                } else if let updated {
                    store.saveTodos(store.todos.map { $0.id == updated.id ? updated : $0 })
                }
                editing = nil
            }
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("New to-do", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTodo)
                Picker("When", selection: $scope) {
                    ForEach(Todos.scopeOrder) { s in
                        Text(Todos.scopeLabels[s] ?? s.rawValue).tag(s)
                    }
                }
                .frame(width: 160)
                Button("Add", action: addTodo)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if scope == .timed {
                HStack {
                    Text("Start")
                    TextField("09:00", text: $startTime).frame(width: 70)
                    Text("End")
                    TextField("10:00", text: $endTime).frame(width: 70)
                }
                .font(.caption)
            }
            if scope == .week {
                Picker("This week ends", selection: $weekMode) {
                    Text("Until Sunday midnight").tag(WeekDueMode.weekEndSunday)
                    Text("7 days from selected day").tag(WeekDueMode.rolling7Days)
                }
            }
            if scope == .month {
                Picker("Month ends", selection: $monthMode) {
                    Text("End of calendar month").tag(MonthDueMode.calendarMonthEnd)
                    Text("Next 30 days").tag(MonthDueMode.rolling30Days)
                }
            }
            HStack {
                ForEach(store.todoTags) { tag in
                    Button {
                        if selectedTagIds.contains(tag.id) { selectedTagIds.remove(tag.id) } else { selectedTagIds.insert(tag.id) }
                    } label: {
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.palette(tag.color).opacity(selectedTagIds.contains(tag.id) ? 0.35 : 0.12), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.palette(tag.color).opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
                TextField("New tag", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Picker("", selection: $newTagColor) {
                    ForEach(PaletteColor.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .frame(width: 90)
                Button("Add tag") {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    var tags = store.todoTags
                    tags.append(TodoTag(id: UUID().uuidString, name: name, color: newTagColor))
                    store.saveTodos(store.todos, tags: tags)
                    newTagName = ""
                }
            }
        }
        .padding(10)
        .background(AppTheme.muted.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    private func column(_ title: String, _ items: [TodoItem], _ scope: TodoScope?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(scope.map { AppTheme.scopeAccent($0) } ?? Color.red)
            if items.isEmpty {
                Text("Nothing here.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
            ForEach(items) { todo in
                todoRow(todo, scope: scope)
                    .onDrag { NSItemProvider(object: todo.id as NSString) }
                    .dropDestination(for: String.self) { dropped, _ in
                        guard let scope, let id = dropped.first else { return false }
                        store.saveTodos(Todos.reorderTodosInScope(store.todos, viewDateKey: viewDate, scope: scope, activeId: id, overId: todo.id))
                        return true
                    }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke((scope.map { AppTheme.scopeAccent($0) } ?? Color.red).opacity(0.35), lineWidth: 2))
    }

    private func todoRow(_ todo: TodoItem, scope: TodoScope?) -> some View {
        let urgent = Todos.isMonthTodoUrgent(todo, viewDateKey: viewDate)
        let due = Todos.formatTodoDueLabel(todo, viewDateKey: viewDate)
        let tags = TodoTags.resolveTags(tagIds: todo.tagIds, catalog: store.todoTags)
        return HStack(spacing: 8) {
            Button {
                var next = todo
                next.completed.toggle()
                store.saveTodos(store.todos.map { $0.id == todo.id ? next : $0 })
            } label: {
                Image(systemName: todo.completed ? "checkmark.square.fill" : "square")
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .strikethrough(todo.completed)
                    .foregroundStyle(todo.completed ? AppTheme.mutedText : AppTheme.text)
                HStack(spacing: 6) {
                    if let due { Text(due).font(.caption2).foregroundStyle(.red) }
                    if todo.scope == .month, let days = Todos.getMonthTodoDaysLeft(todo, viewDateKey: viewDate) {
                        Text(Todos.formatMonthTodoDaysLeftLabel(days)).font(.caption2).foregroundStyle(AppTheme.mutedText)
                    }
                    if todo.scope == .timed {
                        Text(Todos.formatTodoScheduleLabel(todo)).font(.caption2).foregroundStyle(AppTheme.mutedText)
                    }
                    ForEach(tags) { tag in
                        Circle().fill(AppTheme.palette(tag.color)).frame(width: 7, height: 7)
                    }
                }
            }
            Spacer()
            Button { editing = todo } label: { Image(systemName: "pencil") }.buttonStyle(.plain)
            Button {
                store.saveTodos(store.todos.filter { $0.id != todo.id })
            } label: { Image(systemName: "trash") }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.destructive)
        }
        .padding(8)
        .background(AppTheme.secondary, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(urgent ? Color.red : AppTheme.border.opacity(0.5), lineWidth: urgent ? 2 : 1)
        )
    }

    private func addTodo() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let iso = ISO8601DateFormatter().string(from: Date())
        var due: String?
        switch scope {
        case .day, .timed: due = viewDate
        case .week: due = Todos.computeWeekDueDate(anchor: viewDate, mode: weekMode)
        case .month: due = Todos.computeMonthDueDate(anchor: viewDate, mode: monthMode)
        }
        let start = String(startTime.prefix(5))
        let end = Todos.normalizeTimedEndTime(startTime: start, endTime: String(endTime.prefix(5)))
        let item = TodoItem(
            id: UUID().uuidString,
            title: trimmed,
            completed: false,
            scope: scope,
            anchor: viewDate,
            dueDate: due,
            time: scope == .timed ? start : nil,
            endTime: scope == .timed ? end : nil,
            tagIds: Array(selectedTagIds),
            createdAt: iso
        )
        store.saveTodos(store.todos + [item])
        title = ""
    }
}

struct TodoEditorSheet: View {
    var todo: TodoItem
    var tags: [TodoTag]
    var onFinish: (TodoItem?, Bool) -> Void

    @State private var title: String = ""
    @State private var scope: TodoScope = .day
    @State private var startTime = "09:00"
    @State private var endTime = "10:00"
    @State private var anchor = ""
    @State private var weekMode: WeekDueMode = .weekEndSunday
    @State private var monthMode: MonthDueMode = .calendarMonthEnd
    @State private var selectedTagIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit to-do").font(.headline)
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            Picker("When", selection: $scope) {
                ForEach(Todos.scopeOrder) { s in
                    Text(Todos.scopeLabels[s] ?? s.rawValue).tag(s)
                }
            }
            DatePicker("Anchor", selection: Binding(
                get: { DateKeys.parseDateKey(anchor.isEmpty ? todo.anchor : anchor) },
                set: { anchor = DateKeys.formatDateKey($0) }
            ), displayedComponents: .date)
            if scope == .timed {
                HStack {
                    TextField("Start", text: $startTime).frame(width: 80)
                    TextField("End", text: $endTime).frame(width: 80)
                }
            }
            if scope == .week {
                Picker("Week ends", selection: $weekMode) {
                    Text("Until Sunday midnight").tag(WeekDueMode.weekEndSunday)
                    Text("7 days from selected day").tag(WeekDueMode.rolling7Days)
                }
            }
            if scope == .month {
                Picker("Month ends", selection: $monthMode) {
                    Text("End of calendar month").tag(MonthDueMode.calendarMonthEnd)
                    Text("Next 30 days").tag(MonthDueMode.rolling30Days)
                }
            }
            HStack {
                ForEach(tags) { tag in
                    Button {
                        if selectedTagIds.contains(tag.id) { selectedTagIds.remove(tag.id) } else { selectedTagIds.insert(tag.id) }
                    } label: {
                        Text(tag.name)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.palette(tag.color).opacity(selectedTagIds.contains(tag.id) ? 0.35 : 0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Button("Save") { onFinish(build(), false) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel") { onFinish(nil, false) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Delete", role: .destructive) { onFinish(nil, true) }
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            title = todo.title
            scope = todo.scope
            startTime = todo.time ?? "09:00"
            endTime = todo.endTime ?? Todos.getTodoEndTime(todo)
            anchor = todo.anchor
            selectedTagIds = Set(todo.tagIds)
        }
    }

    private func build() -> TodoItem {
        let a = anchor.isEmpty ? todo.anchor : anchor
        var due = todo.dueDate
        switch scope {
        case .day, .timed: due = a
        case .week: due = Todos.computeWeekDueDate(anchor: a, mode: weekMode)
        case .month: due = Todos.computeMonthDueDate(anchor: a, mode: monthMode)
        }
        return TodoItem(
            id: todo.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            completed: todo.completed,
            scope: scope,
            anchor: a,
            dueDate: due,
            time: scope == .timed ? String(startTime.prefix(5)) : nil,
            endTime: scope == .timed ? Todos.normalizeTimedEndTime(startTime: startTime, endTime: endTime) : nil,
            tagIds: Array(selectedTagIds),
            createdAt: todo.createdAt
        )
    }
}
