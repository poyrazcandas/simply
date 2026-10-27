import Foundation

enum Todos {
    static let scopeLabels: [TodoScope: String] = [
        .timed: "Specific time",
        .day: "This day",
        .week: "This week",
        .month: "This month",
    ]

    static let scopeOrder: [TodoScope] = [.timed, .day, .week, .month]
    static let defaultTimedDurationMinutes = 60
    static let monthUrgentDaysThreshold = 3

    static func parseTimeMinutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    static func formatTimeFromMinutes(_ total: Int) -> String {
        let day = 24 * 60
        let normalized = ((total % day) + day) % day
        let h = normalized / 60
        let m = normalized % 60
        return String(format: "%02d:%02d", h, m)
    }

    static func addMinutesToTime(_ time: String, _ minutes: Int) -> String {
        formatTimeFromMinutes(parseTimeMinutes(time) + minutes)
    }

    static func getTodoEndTime(_ todo: TodoItem) -> String {
        let start = todo.time ?? "09:00"
        if let end = todo.endTime, parseTimeMinutes(end) > parseTimeMinutes(start) {
            return end
        }
        return addMinutesToTime(start, defaultTimedDurationMinutes)
    }

    static func normalizeTimedEndTime(startTime: String, endTime: String?) -> String {
        let start = String(startTime.prefix(5))
        if let endTime {
            let end = String(endTime.prefix(5))
            if parseTimeMinutes(end) > parseTimeMinutes(start) { return end }
        }
        return addMinutesToTime(start, defaultTimedDurationMinutes)
    }

    /// Upcoming Sunday of the Sun–Sat week containing dateKey.
    static func getSundayOfWeekContaining(_ dateKey: String) -> String {
        let dow = DateKeys.weekdaySundayIndexed(dateKey) // Sun=1 … Sat=7
        if dow == 1 { return String(dateKey.prefix(10)) }
        return DateKeys.addDays(dateKey, 8 - dow)
    }

    static func getCalendarMonthEnd(_ dateKey: String) -> String {
        let date = DateKeys.parseDateKey(String(dateKey.prefix(10)))
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .month, for: date)
        let last = interval.flatMap { cal.date(byAdding: .day, value: -1, to: $0.end) } ?? date
        return DateKeys.formatDateKey(last)
    }

    static func computeWeekDueDate(anchor: String, mode: WeekDueMode) -> String {
        let a = String(anchor.prefix(10))
        if mode == .rolling7Days { return DateKeys.addDays(a, 7) }
        return getSundayOfWeekContaining(a)
    }

    static func computeMonthDueDate(anchor: String, mode: MonthDueMode) -> String {
        let a = String(anchor.prefix(10))
        if mode == .rolling30Days { return DateKeys.addDays(a, 30) }
        return getCalendarMonthEnd(a)
    }

    static func getTodoStartDate(_ todo: TodoItem) -> String {
        if todo.scope == .month, todo.anchor.count == 7 {
            return "\(todo.anchor)-01"
        }
        return String(todo.anchor.prefix(10))
    }

    static func getTodoDueDate(_ todo: TodoItem) -> String {
        if let due = todo.dueDate { return String(due.prefix(10)) }
        let start = getTodoStartDate(todo)
        switch todo.scope {
        case .day, .timed: return start
        case .week: return getSundayOfWeekContaining(start)
        case .month: return getCalendarMonthEnd(start)
        }
    }

    static func normalizeTodos(_ todos: [TodoItem]) -> [TodoItem] {
        todos.compactMap { t in
            guard !t.id.isEmpty else { return nil }
            let scope = TodoScope(rawValue: t.scope.rawValue) ?? .day
            let anchorRaw = t.anchor.count >= 7 ? t.anchor : DateKeys.formatDateKey(Date())
            let anchor = (scope == .month && anchorRaw.count == 7) ? "\(anchorRaw)-01" : String(anchorRaw.prefix(10))
            var dueDate: String? = t.dueDate.map { String($0.prefix(10)) }
            if scope == .week && dueDate == nil { dueDate = getSundayOfWeekContaining(anchor) }
            if scope == .month && dueDate == nil { dueDate = getCalendarMonthEnd(anchor) }
            if (scope == .day || scope == .timed) && dueDate == nil { dueDate = anchor }
            let title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return TodoItem(
                id: t.id,
                title: title,
                completed: t.completed,
                scope: scope,
                anchor: anchor,
                dueDate: dueDate,
                time: scope == .timed ? t.time.map { String($0.prefix(5)) } : nil,
                endTime: scope == .timed && t.time != nil
                    ? normalizeTimedEndTime(startTime: String((t.time ?? "").prefix(5)), endTime: t.endTime.map { String($0.prefix(5)) })
                    : nil,
                tagIds: t.tagIds,
                createdAt: t.createdAt.isEmpty ? ISO8601DateFormatter().string(from: Date()) : t.createdAt
            )
        }
    }

    static func todoVisibleOnDate(_ todo: TodoItem, viewDateKey: String) -> Bool {
        let start = getTodoStartDate(todo)
        let due = getTodoDueDate(todo)
        if todo.scope == .day || todo.scope == .timed {
            return viewDateKey == start
        }
        return viewDateKey >= start && viewDateKey <= due
    }

    static func eachDateInRange(startKey: String, endKey: String) -> [String] {
        var dates: [String] = []
        var cursor = startKey
        while cursor <= endKey {
            dates.append(cursor)
            cursor = DateKeys.addDays(cursor, 1)
        }
        return dates
    }

    static func getTimedEventDateKeys(_ todos: [TodoItem]) -> Set<String> {
        Set(todos.filter { $0.scope == .timed }.map { getTodoStartDate($0) })
    }

    struct GroupedTodos {
        var timed: [TodoItem]
        var day: [TodoItem]
        var week: [TodoItem]
        var month: [TodoItem]
        var pastDue: [TodoItem]
    }

    static func groupTodosForDate(_ todos: [TodoItem], viewDateKey: String, todayKey: String? = nil) -> GroupedTodos {
        let applicable = todos.filter { todoVisibleOnDate($0, viewDateKey: viewDateKey) }
        var pastDue: [TodoItem] = []
        if let todayKey, viewDateKey == todayKey {
            for todo in todos where !todo.completed {
                let due = getTodoDueDate(todo)
                if due < todayKey && !applicable.contains(where: { $0.id == todo.id }) {
                    pastDue.append(todo)
                }
            }
        }
        return GroupedTodos(
            timed: applicable.filter { $0.scope == .timed },
            day: applicable.filter { $0.scope == .day },
            week: applicable.filter { $0.scope == .week },
            month: applicable.filter { $0.scope == .month },
            pastDue: pastDue
        )
    }

    struct OpenCounts: Equatable {
        var timed: Int
        var day: Int
        var week: Int
        var month: Int
        var pastDue: Int
    }

    static func getOpenTodoCountsForDate(_ todos: [TodoItem], viewDateKey: String) -> OpenCounts {
        let grouped = groupTodosForDate(todos, viewDateKey: viewDateKey, todayKey: viewDateKey)
        func open(_ items: [TodoItem]) -> Int { items.filter { !$0.completed }.count }
        return OpenCounts(
            timed: open(grouped.timed),
            day: open(grouped.day),
            week: open(grouped.week),
            month: open(grouped.month),
            pastDue: grouped.pastDue.count
        )
    }

    static func reorderTodosInScope(
        _ todos: [TodoItem],
        viewDateKey: String,
        scope: TodoScope,
        activeId: String,
        overId: String? = nil
    ) -> [TodoItem] {
        guard let active = todos.first(where: { $0.id == activeId }),
              active.scope == scope,
              todoVisibleOnDate(active, viewDateKey: viewDateKey)
        else { return todos }
        if overId == activeId { return todos }

        let visibleInScope = todos.filter { $0.scope == scope && todoVisibleOnDate($0, viewDateKey: viewDateKey) }
        let visibleIds = Set(visibleInScope.map(\.id))
        var orderedIds = visibleInScope.map(\.id).filter { $0 != activeId }

        if let overId, visibleIds.contains(overId), let overIndex = orderedIds.firstIndex(of: overId) {
            orderedIds.insert(activeId, at: overIndex)
        } else {
            orderedIds.append(activeId)
        }

        let idToTodo = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        var nextIndex = 0
        return todos.map { todo in
            if visibleIds.contains(todo.id) {
                let id = orderedIds[nextIndex]
                nextIndex += 1
                return idToTodo[id] ?? todo
            }
            return todo
        }
    }

    static func getMonthTodoDaysLeft(_ todo: TodoItem, viewDateKey: String) -> Int? {
        guard todo.scope == .month else { return nil }
        return DateKeys.daysBetween(viewDateKey, getTodoDueDate(todo))
    }

    static func formatMonthTodoDaysLeftLabel(_ daysLeft: Int) -> String {
        if daysLeft <= 0 { return "0 days left" }
        if daysLeft == 1 { return "1 day left" }
        return "\(daysLeft) days left"
    }

    static func isMonthTodoUrgent(_ todo: TodoItem, viewDateKey: String) -> Bool {
        guard todo.scope == .month, !todo.completed else { return false }
        guard let daysLeft = getMonthTodoDaysLeft(todo, viewDateKey: viewDateKey) else { return false }
        return daysLeft >= 0 && daysLeft <= monthUrgentDaysThreshold
    }

    static func formatTodoDueLabel(_ todo: TodoItem, viewDateKey: String) -> String? {
        if todo.scope == .week {
            let due = getTodoDueDate(todo)
            let days = DateKeys.daysBetween(viewDateKey, due)
            if days <= 0 { return "due today" }
            if days == 1 { return "due 1 day" }
            return "due \(days) days"
        }
        if todo.scope == .month {
            let due = DateKeys.parseDateKey(getTodoDueDate(todo))
            let d = Calendar.current.component(.day, from: due)
            let m = Calendar.current.component(.month, from: due)
            return "due \(d)/\(m)"
        }
        return nil
    }

    static func formatTodoScheduleLabel(_ todo: TodoItem) -> String {
        switch todo.scope {
        case .day: return "All day"
        case .timed:
            guard let time = todo.time else { return "—" }
            return "\(time) – \(getTodoEndTime(todo))"
        default: return ""
        }
    }
}
