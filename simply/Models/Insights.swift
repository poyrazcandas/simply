import Foundation

struct HabitImpact: Identifiable {
    var habitId: String
    var title: String
    var category: HabitCategory
    var avgRatingWhenCompleted: Double?
    var avgRatingWhenMissed: Double?
    var impact: Double?
    var completedDays: Int
    var missedDays: Int
    var hasEnoughData: Bool
    var id: String { habitId }
}

struct TimeBlockImpact: Identifiable {
    var category: HabitCategory
    var label: String
    var avgRating: Double?
    var blockCompleteDays: Int
    var eligibleDays: Int
    var habitCount: Int
    var id: HabitCategory { category }
}

struct HabitStreakStats: Identifiable {
    var habitId: String
    var title: String
    var category: HabitCategory
    var currentStreak: Int
    var bestStreak: Int
    var neverMissTwice: Bool
    var id: String { habitId }
}

struct InsightsPayload {
    var habitImpacts: [HabitImpact]
    var timeBlockImpacts: [TimeBlockImpact]
    var habitStreaks: [HabitStreakStats]
    var perfectDayCount: Int
    var totalLoggedDays: Int
    var today: String
}

enum Insights {
    static func compute(_ data: TrackerData, today: String = DateKeys.formatDateKey(Date())) -> InsightsPayload {
        let habits = data.habits
        let logs = data.logs
        let ratedLogs = logs.values.filter { (1...10).contains($0.rating) }
        let sortedDates = logs.keys.sorted()

        var streaks = habits.map { habit in
            HabitStreakStats(
                habitId: habit.id,
                title: habit.title,
                category: habit.category,
                currentStreak: currentStreak(habitId: habit.id, logs: logs, today: today),
                bestStreak: bestStreak(habitId: habit.id, sortedDates: sortedDates, logs: logs),
                neverMissTwice: neverMissTwice(habitId: habit.id, logs: logs, today: today)
            )
        }
        streaks.sort { $0.currentStreak > $1.currentStreak }

        return InsightsPayload(
            habitImpacts: habitImpacts(habits: habits, ratedLogs: ratedLogs),
            timeBlockImpacts: timeBlockImpacts(habits: habits, ratedLogs: ratedLogs),
            habitStreaks: streaks,
            perfectDayCount: ratedLogs.filter { DailyProgress.isPerfectDay(habits: habits, log: $0) }.count,
            totalLoggedDays: ratedLogs.count,
            today: today
        )
    }

    static func impactLabel(_ impact: Double?) -> String {
        guard let impact else { return "Not enough data" }
        if impact > 0.5 { return "Strong positive" }
        if impact > 0 { return "Positive" }
        if impact < -0.5 { return "Negative" }
        if impact < 0 { return "Slight negative" }
        return "Neutral"
    }

    private static func average(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func isCompleted(_ habitId: String, log: DailyLog) -> Bool {
        log.completedHabitIds.contains(habitId)
    }

    private static func currentStreak(habitId: String, logs: [String: DailyLog], today: String) -> Int {
        var streak = 0
        var cursor = today
        if let todayLog = logs[today], !isCompleted(habitId, log: todayLog) {
            cursor = DateKeys.addDays(today, -1)
        }
        while let log = logs[cursor] {
            if !isCompleted(habitId, log: log) { break }
            streak += 1
            cursor = DateKeys.addDays(cursor, -1)
        }
        return streak
    }

    private static func bestStreak(habitId: String, sortedDates: [String], logs: [String: DailyLog]) -> Int {
        var best = 0
        var current = 0
        for date in sortedDates {
            if let log = logs[date], isCompleted(habitId, log: log) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    private static func neverMissTwice(habitId: String, logs: [String: DailyLog], today: String) -> Bool {
        let yesterday = DateKeys.addDays(today, -1)
        guard let yesterdayLog = logs[yesterday] else { return false }
        if isCompleted(habitId, log: yesterdayLog) { return false }
        guard let todayLog = logs[today] else { return true }
        return !isCompleted(habitId, log: todayLog)
    }

    private static func habitImpacts(habits: [Habit], ratedLogs: [DailyLog]) -> [HabitImpact] {
        habits.map { habit in
            var completedRatings: [Int] = []
            var missedRatings: [Int] = []
            for log in ratedLogs {
                if isCompleted(habit.id, log: log) {
                    completedRatings.append(log.rating)
                } else {
                    missedRatings.append(log.rating)
                }
            }
            let doneAvg = average(completedRatings)
            let missedAvg = average(missedRatings)
            let enough = !completedRatings.isEmpty && !missedRatings.isEmpty
            let impactFixed: Double? = {
                guard enough, let doneAvg, let missedAvg else { return nil }
                return (doneAvg - missedAvg).rounded(toPlaces: 2)
            }()
            return HabitImpact(
                habitId: habit.id,
                title: habit.title,
                category: habit.category,
                avgRatingWhenCompleted: doneAvg?.rounded(toPlaces: 2),
                avgRatingWhenMissed: missedAvg?.rounded(toPlaces: 2),
                impact: impactFixed,
                completedDays: completedRatings.count,
                missedDays: missedRatings.count,
                hasEnoughData: enough
            )
        }
        .sorted { a, b in
            switch (a.impact, b.impact) {
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            case let (l?, r?): return l > r
            }
        }
    }

    private static func timeBlockImpacts(habits: [Habit], ratedLogs: [DailyLog]) -> [TimeBlockImpact] {
        Categories.order.map { category in
            let blockHabits = habits.filter { $0.category == category }
            if blockHabits.isEmpty {
                return TimeBlockImpact(
                    category: category,
                    label: Categories.labels[category] ?? category.rawValue,
                    avgRating: nil,
                    blockCompleteDays: 0,
                    eligibleDays: 0,
                    habitCount: 0
                )
            }
            var ratings: [Int] = []
            for log in ratedLogs {
                let block = DailyProgress.getBlockProgress(
                    habits: habits,
                    category: category,
                    completedIds: Set(log.completedHabitIds),
                    fullTime: DailyProgress.isLogFullTime(log)
                )
                if block.isComplete {
                    ratings.append(log.rating)
                }
            }
            return TimeBlockImpact(
                category: category,
                label: Categories.labels[category] ?? category.rawValue,
                avgRating: average(ratings)?.rounded(toPlaces: 2),
                blockCompleteDays: ratings.count,
                eligibleDays: ratedLogs.count,
                habitCount: blockHabits.count
            )
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
