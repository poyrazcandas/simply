import Foundation

enum HabitCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case morning
    case dayActivities = "day-activities"
    case dayHabits = "day-habits"
    case night

    var id: String { rawValue }
}

struct Habit: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var category: HabitCategory

    enum CodingKeys: String, CodingKey {
        case id, title, category
    }

    init(id: String, title: String, category: HabitCategory) {
        self.id = id
        self.title = title
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        if let decoded = try? c.decode(HabitCategory.self, forKey: .category) {
            category = decoded
        } else {
            let raw = (try? c.decode(String.self, forKey: .category)) ?? "day-activities"
            category = Categories.normalizeHabitCategory(raw)
        }
    }
}

struct DailyLog: Identifiable, Codable, Hashable {
    var date: String
    var completedHabitIds: [String]
    var highlight: String
    var rating: Int
    var fullTime: Bool?

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date, completedHabitIds, highlight, rating, fullTime
    }

    init(
        date: String,
        completedHabitIds: [String] = [],
        highlight: String = "",
        rating: Int = 5,
        fullTime: Bool? = true
    ) {
        self.date = date
        self.completedHabitIds = completedHabitIds
        self.highlight = highlight
        self.rating = DailyLog.clampRating(rating)
        self.fullTime = fullTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        completedHabitIds = try c.decodeIfPresent([String].self, forKey: .completedHabitIds) ?? []
        highlight = try c.decodeIfPresent(String.self, forKey: .highlight) ?? ""
        rating = DailyLog.clampRating(try c.decodeIfPresent(Int.self, forKey: .rating) ?? 5)
        fullTime = try c.decodeIfPresent(Bool.self, forKey: .fullTime)
    }

    static let `default` = DailyLog(date: "", completedHabitIds: [], highlight: "", rating: 5, fullTime: true)

    static func clampRating(_ value: Int) -> Int {
        min(10, max(1, value))
    }

    static func blank(date: String) -> DailyLog {
        DailyLog(date: date, completedHabitIds: [], highlight: "", rating: 5, fullTime: true)
    }
}

enum TodoScope: String, Codable, CaseIterable, Identifiable, Hashable {
    case day, week, month, timed
    var id: String { rawValue }
}

enum WeekDueMode: String, Codable, Hashable {
    case weekEndSunday = "week-end-sunday"
    case rolling7Days = "rolling-7-days"
}

enum MonthDueMode: String, Codable, Hashable {
    case calendarMonthEnd = "calendar-month-end"
    case rolling30Days = "rolling-30-days"
}

enum PaletteColor: String, Codable, CaseIterable, Identifiable, Hashable {
    case violet, sky, emerald, amber, rose, cyan, orange, fuchsia
    var id: String { rawValue }
}

struct TodoTag: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var color: PaletteColor
}

struct TodoItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var completed: Bool
    var scope: TodoScope
    var anchor: String
    var dueDate: String?
    var time: String?
    var endTime: String?
    var tagIds: [String]
    var createdAt: String
}

struct ImportedCalendarEvent: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var startDate: String
    var endDate: String
    var allDay: Bool
    var startTime: String?
    var endTime: String?
    var description: String?
}

struct CalendarSource: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var color: PaletteColor
    var enabled: Bool
    var events: [ImportedCalendarEvent]
    var importedAt: String
}

struct TrackerData: Codable, Hashable {
    var habits: [Habit]
    var logs: [String: DailyLog]
    var todos: [TodoItem]
    var todoTags: [TodoTag]
    var calendarSources: [CalendarSource]

    static let empty = TrackerData(
        habits: [],
        logs: [:],
        todos: [],
        todoTags: [],
        calendarSources: []
    )

    enum CodingKeys: String, CodingKey {
        case habits, logs, todos, todoTags, calendarSources
    }

    init(
        habits: [Habit],
        logs: [String: DailyLog],
        todos: [TodoItem],
        todoTags: [TodoTag],
        calendarSources: [CalendarSource]
    ) {
        self.habits = habits
        self.logs = logs
        self.todos = todos
        self.todoTags = todoTags
        self.calendarSources = calendarSources
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        habits = try c.decodeIfPresent([Habit].self, forKey: .habits) ?? []
        logs = try c.decodeIfPresent([String: DailyLog].self, forKey: .logs) ?? [:]
        todos = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        todoTags = try c.decodeIfPresent([TodoTag].self, forKey: .todoTags) ?? []
        calendarSources = try c.decodeIfPresent([CalendarSource].self, forKey: .calendarSources) ?? []
    }
}

enum SpecialHabitID {
    static let completeTodos = "__complete-todos__"
    static let plannedNextDay = "__planned-next-day__"
    static let plannedNextDayTitle = "Planned Next Day"
}
