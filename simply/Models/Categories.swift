import Foundation

enum Categories {
    static let order: [HabitCategory] = [.morning, .dayActivities, .dayHabits, .night]

    static let labels: [HabitCategory: String] = [
        .morning: "Morning Routine",
        .dayActivities: "Day Boosters",
        .dayHabits: "Day Habits",
        .night: "Night Routine",
    ]

    static let emptyMessages: [HabitCategory: String] = [
        .morning: "No morning habits yet.",
        .dayActivities: "No day boosters yet.",
        .dayHabits: "No day habits yet. Add routines you want every day.",
        .night: "No night habits yet.",
    ]

    static func normalizeHabitCategory(_ raw: String) -> HabitCategory {
        if raw == "day" { return .dayActivities }
        return HabitCategory(rawValue: raw) ?? .dayActivities
    }

    static func normalizeHabits(_ habits: [Habit]) -> [Habit] {
        habits.map { habit in
            var next = habit
            next.category = normalizeHabitCategory(habit.category.rawValue)
            return next
        }
    }

    static func groupHabitsByCategory(_ habits: [Habit]) -> [HabitCategory: [Habit]] {
        let normalized = normalizeHabits(habits)
        var grouped: [HabitCategory: [Habit]] = [
            .morning: [],
            .dayActivities: [],
            .dayHabits: [],
            .night: [],
        ]
        for habit in normalized {
            grouped[habit.category, default: []].append(habit)
        }
        return grouped
    }
}
