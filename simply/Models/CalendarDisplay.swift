import Foundation

enum CalendarEntryKind: String, Hashable {
    case todoDay = "todo-day"
    case todoTimed = "todo-timed"
    case todoWeekDue = "todo-week-due"
    case todoMonthDue = "todo-month-due"
    case imported
}

struct CalendarDisplayEntry: Identifiable, Hashable {
    var id: String
    var title: String
    var kind: CalendarEntryKind
    var dateKey: String
    var startTime: String?
    var endTime: String?
    var allDay: Bool
    var color: PaletteColor
    var completed: Bool?
    var subtitle: String?
    var sourceName: String?
    var todoId: String?
}

enum CalendarDisplay {
    static let hourHeight: CGFloat = 48
    static let hours = Array(0..<24)
    static let weekdayHeaders = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static func getTodoCalendarEntries(todos: [TodoItem], dateKey: String) -> [CalendarDisplayEntry] {
        var entries: [CalendarDisplayEntry] = []
        for todo in todos {
            if todo.scope == .day, Todos.todoVisibleOnDate(todo, viewDateKey: dateKey) {
                entries.append(
                    CalendarDisplayEntry(
                        id: "todo-\(todo.id)",
                        title: todo.title,
                        kind: .todoDay,
                        dateKey: dateKey,
                        allDay: true,
                        color: .sky,
                        completed: todo.completed,
                        subtitle: "This day",
                        todoId: todo.id
                    )
                )
            }
            if todo.scope == .timed, Todos.getTodoStartDate(todo) == dateKey {
                let end = Todos.getTodoEndTime(todo)
                entries.append(
                    CalendarDisplayEntry(
                        id: "todo-\(todo.id)",
                        title: todo.title,
                        kind: .todoTimed,
                        dateKey: dateKey,
                        startTime: todo.time ?? "09:00",
                        endTime: end,
                        allDay: false,
                        color: .violet,
                        completed: todo.completed,
                        subtitle: todo.time.map { "\($0) – \(end)" } ?? "Timed",
                        todoId: todo.id
                    )
                )
            }
            if todo.scope == .week, Todos.todoVisibleOnDate(todo, viewDateKey: dateKey) {
                entries.append(
                    CalendarDisplayEntry(
                        id: "todo-week-\(todo.id)-\(dateKey)",
                        title: todo.title,
                        kind: .todoWeekDue,
                        dateKey: dateKey,
                        allDay: true,
                        color: .amber,
                        completed: todo.completed,
                        subtitle: Todos.formatTodoDueLabel(todo, viewDateKey: dateKey) ?? "Week due",
                        todoId: todo.id
                    )
                )
            }
            if todo.scope == .month, Todos.todoVisibleOnDate(todo, viewDateKey: dateKey) {
                let daysLeft = Todos.getMonthTodoDaysLeft(todo, viewDateKey: dateKey)
                let dueLabel = Todos.formatTodoDueLabel(todo, viewDateKey: dateKey) ?? "Month due"
                let daysLeftLabel = daysLeft.map { Todos.formatMonthTodoDaysLeftLabel($0) }
                entries.append(
                    CalendarDisplayEntry(
                        id: "todo-month-\(todo.id)-\(dateKey)",
                        title: todo.title,
                        kind: .todoMonthDue,
                        dateKey: dateKey,
                        allDay: true,
                        color: .emerald,
                        completed: todo.completed,
                        subtitle: daysLeftLabel.map { "\(dueLabel) · \($0)" } ?? dueLabel,
                        todoId: todo.id
                    )
                )
            }
        }
        return entries
    }

    static func getImportedCalendarEntries(sources: [CalendarSource], dateKey: String) -> [CalendarDisplayEntry] {
        var entries: [CalendarDisplayEntry] = []
        for source in sources where source.enabled {
            for event in source.events where dateKey >= event.startDate && dateKey <= event.endDate {
                entries.append(
                    CalendarDisplayEntry(
                        id: "imported-\(source.id)-\(event.id)-\(dateKey)",
                        title: event.title,
                        kind: .imported,
                        dateKey: dateKey,
                        startTime: event.allDay ? nil : event.startTime,
                        endTime: event.allDay ? nil : event.endTime,
                        allDay: event.allDay,
                        color: source.color,
                        sourceName: source.name
                    )
                )
            }
        }
        return entries
    }

    static func getAllEntries(
        todos: [TodoItem],
        sources: [CalendarSource],
        dateKey: String,
        includeTodos: Bool = true,
        includeImported: Bool = true
    ) -> [CalendarDisplayEntry] {
        let todoEntries = includeTodos ? getTodoCalendarEntries(todos: todos, dateKey: dateKey) : []
        let imported = includeImported ? getImportedCalendarEntries(sources: sources, dateKey: dateKey) : []
        return todoEntries + imported
    }

    struct SplitEntries {
        var weekMonth: [CalendarDisplayEntry]
        var allDay: [CalendarDisplayEntry]
        var timed: [CalendarDisplayEntry]
    }

    static func splitEntries(_ entries: [CalendarDisplayEntry]) -> SplitEntries {
        let weekMonth = entries.filter { $0.kind == .todoWeekDue || $0.kind == .todoMonthDue }
        let allDay = entries.filter { $0.allDay && $0.kind != .todoWeekDue && $0.kind != .todoMonthDue }
        let timed = entries
            .filter { !$0.allDay && $0.startTime != nil }
            .sorted { Todos.parseTimeMinutes($0.startTime ?? "00:00") < Todos.parseTimeMinutes($1.startTime ?? "00:00") }
        return SplitEntries(weekMonth: weekMonth, allDay: allDay, timed: timed)
    }

    static func getWeekDaysAround(_ dateKey: String) -> [String] {
        let date = DateKeys.parseDateKey(dateKey)
        let start = DateKeys.addDays(dateKey, -DateKeys.daysFromMonday(date))
        return (0..<7).map { DateKeys.addDays(start, $0) }
    }

    static func getMonthGridDays(year: Int, month: Int) -> [String] {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let cal = Calendar.current
        let first = cal.date(from: comps) ?? Date()
        let startOffset = DateKeys.daysFromMonday(first)
        let start = cal.date(byAdding: .day, value: -startOffset, to: first) ?? first
        return (0..<42).map { i in
            DateKeys.formatDateKey(cal.date(byAdding: .day, value: i, to: start) ?? start)
        }
    }

    static func entryDurationMinutes(_ entry: CalendarDisplayEntry) -> Int {
        guard let startTime = entry.startTime, let endTime = entry.endTime else { return 60 }
        var endMinutes = Todos.parseTimeMinutes(endTime)
        let startMinutes = Todos.parseTimeMinutes(startTime)
        if endMinutes <= startMinutes { endMinutes += 24 * 60 }
        return max(15, endMinutes - startMinutes)
    }

    static func entryTopOffset(_ entry: CalendarDisplayEntry, hourHeight: CGFloat = hourHeight) -> CGFloat {
        guard let startTime = entry.startTime else { return 0 }
        let minutes = CGFloat(Todos.parseTimeMinutes(startTime))
        return (minutes / 60) * hourHeight
    }

    static func entryHeight(entry: CalendarDisplayEntry, hourHeight: CGFloat = hourHeight, gridHeight: CGFloat) -> CGFloat {
        let top = entryTopOffset(entry, hourHeight: hourHeight)
        let rawHeight = CGFloat(entryDurationMinutes(entry)) / 60 * hourHeight
        return min(rawHeight, max(0, gridHeight - top))
    }

    static func snapMinutes(_ minutes: Int, interval: Int = 15) -> Int {
        Int((Double(minutes) / Double(interval)).rounded()) * interval
    }

    static func gridYToTimeMinutes(_ y: CGFloat, hourHeight: CGFloat = hourHeight, snapInterval: Int = 15) -> Int {
        let raw = (y / hourHeight) * 60
        let clamped = max(0, min(Double(24 * 60 - snapInterval), Double(raw)))
        return snapMinutes(Int(clamped.rounded()), interval: snapInterval)
    }

    static func timeMinutesToGridY(_ minutes: Int, hourHeight: CGFloat = hourHeight) -> CGFloat {
        CGFloat(minutes) / 60 * hourHeight
    }

    static func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "12 PM" }
        if hour < 12 { return "\(hour) AM" }
        return "\(hour - 12) PM"
    }
}
