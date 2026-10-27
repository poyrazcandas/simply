import Foundation

enum DailyProgress {
    static let dayActivitiesRequired = 1
    static let dayHabitsRequired = 1
    static let morningNightGrace = 2
    static let partTimeExtraRequired = 1

    static func isLogFullTime(_ log: DailyLog) -> Bool {
        DateKeys.isFullTimeDay(log.date)
    }

    static func requiredCount(category: HabitCategory, total: Int, fullTime: Bool) -> Int {
        var required: Int
        if category == .dayActivities {
            required = dayActivitiesRequired
        } else if category == .dayHabits {
            required = dayHabitsRequired
        } else {
            required = max(1, total - morningNightGrace)
        }
        if !fullTime {
            required += partTimeExtraRequired
        }
        return required
    }

    struct BlockProgress: Equatable {
        var percent: Int
        var display: String
        var isComplete: Bool
        var hasHabits: Bool
        var todosChecked: Bool?
        var plannedNextDayChecked: Bool?
    }

    static func getBlockProgress(
        habits: [Habit],
        category: HabitCategory,
        completedIds: Set<String>,
        fullTime: Bool = true
    ) -> BlockProgress {
        let block = habits.filter { $0.category == category }
        let completed = block.filter { completedIds.contains($0.id) }.count

        if category == .night {
            let plannedNextDayChecked = Features.dailyProgress
                ? completedIds.contains(SpecialHabitID.plannedNextDay)
                : true

            if block.isEmpty {
                if !Features.dailyProgress {
                    return BlockProgress(
                        percent: 0,
                        display: "—",
                        isComplete: false,
                        hasHabits: false,
                        plannedNextDayChecked: true
                    )
                }
                return BlockProgress(
                    percent: plannedNextDayChecked ? 100 : 0,
                    display: plannedNextDayChecked ? "1/1" : "0/1",
                    isComplete: plannedNextDayChecked,
                    hasHabits: true,
                    plannedNextDayChecked: plannedNextDayChecked
                )
            }

            let required = requiredCount(category: category, total: block.count, fullTime: fullTime)
            let percent = min(100, Int(round(Double(completed) / Double(max(required, 1)) * 100)))
            return BlockProgress(
                percent: percent,
                display: "\(min(completed, required))/\(required)",
                isComplete: completed >= required && plannedNextDayChecked,
                hasHabits: true,
                plannedNextDayChecked: plannedNextDayChecked
            )
        }

        if block.isEmpty {
            return BlockProgress(percent: 0, display: "—", isComplete: false, hasHabits: false)
        }

        let required = requiredCount(category: category, total: block.count, fullTime: fullTime)
        let percent = min(100, Int(round(Double(completed) / Double(max(required, 1)) * 100)))

        if category == .dayActivities {
            let todosChecked = Features.todoCalendar
                ? completedIds.contains(SpecialHabitID.completeTodos)
                : true
            return BlockProgress(
                percent: percent,
                display: "\(min(completed, required))/\(required)",
                isComplete: completed >= required && todosChecked,
                hasHabits: true,
                todosChecked: todosChecked
            )
        }

        return BlockProgress(
            percent: percent,
            display: "\(min(completed, required))/\(required)",
            isComplete: completed >= required,
            hasHabits: true
        )
    }

    static func isPerfectDay(habits: [Habit], completedIds: Set<String>, fullTime: Bool = true) -> Bool {
        let morning = getBlockProgress(habits: habits, category: .morning, completedIds: completedIds, fullTime: fullTime)
        let dayActivities = getBlockProgress(habits: habits, category: .dayActivities, completedIds: completedIds, fullTime: fullTime)
        let dayHabits = getBlockProgress(habits: habits, category: .dayHabits, completedIds: completedIds, fullTime: fullTime)
        let night = getBlockProgress(habits: habits, category: .night, completedIds: completedIds, fullTime: fullTime)

        let morningOk = !morning.hasHabits || morning.isComplete
        let nightOk = !night.hasHabits || night.isComplete
        let dayActivitiesOk = !dayActivities.hasHabits || dayActivities.isComplete
        let dayHabitsOk = !dayHabits.hasHabits || dayHabits.isComplete
        return morningOk && nightOk && dayActivitiesOk && dayHabitsOk
    }

    static func isPerfectDay(habits: [Habit], log: DailyLog) -> Bool {
        isPerfectDay(habits: habits, completedIds: Set(log.completedHabitIds), fullTime: isLogFullTime(log))
    }

    static func computeCompleteDayCount(habits: [Habit], logs: [String: DailyLog]) -> Int {
        logs.values.filter { isPerfectDay(habits: habits, log: $0) }.count
    }
}
