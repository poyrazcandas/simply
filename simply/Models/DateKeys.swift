import Foundation

enum DateKeys {
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    static func formatDateKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0
        let m = c.month ?? 1
        let d = c.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func parseDateKey(_ key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 3 else { return calendar.startOfDay(for: Date()) }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? calendar.startOfDay(for: Date())
    }

    static func addDays(_ key: String, _ delta: Int) -> String {
        let date = parseDateKey(key)
        let next = calendar.date(byAdding: .day, value: delta, to: date) ?? date
        return formatDateKey(next)
    }

    static func daysBetween(_ fromKey: String, _ toKey: String) -> Int {
        let from = parseDateKey(fromKey)
        let to = parseDateKey(toKey)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    static func isToday(_ key: String, today: String? = nil) -> Bool {
        key == (today ?? formatDateKey(Date()))
    }

    static func formatDisplayDate(_ key: String, today: String? = nil) -> String {
        let date = parseDateKey(key)
        let todayKey = today ?? formatDateKey(Date())
        let yesterday = addDays(todayKey, -1)
        let tomorrow = addDays(todayKey, 1)

        let includeYear = calendar.component(.year, from: date) != calendar.component(.year, from: Date())
        var formatted = date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .month(.wide)
                .day()
        )
        if includeYear {
            formatted = date.formatted(
                Date.FormatStyle()
                    .weekday(.wide)
                    .month(.wide)
                    .day()
                    .year()
            )
        }

        if key == todayKey { return "Today · \(formatted)" }
        if key == yesterday { return "Yesterday · \(formatted)" }
        if key == tomorrow { return "Tomorrow · \(formatted)" }
        return formatted
    }

    static func msUntilNextLocalMidnight(from now: Date = Date()) -> TimeInterval {
        let start = calendar.startOfDay(for: now)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return max(0, next.timeIntervalSince(now)) + 0.05
    }

    /// Days since Monday (Mon=0 … Sun=6).
    static func daysFromMonday(_ date: Date) -> Int {
        let dow = calendar.component(.weekday, from: date) // Sun=1
        return (dow + 5) % 7
    }

    static func weekdaySundayIndexed(_ key: String) -> Int {
        calendar.component(.weekday, from: parseDateKey(key))
    }

    /// Saturday or Sunday in the local calendar.
    static func isWeekend(_ key: String) -> Bool {
        let dow = weekdaySundayIndexed(key) // Sunday = 1, Saturday = 7
        return dow == 1 || dow == 7
    }

    /// Weekdays use standard (full-time) quotas; weekends use the part-time extra.
    static func isFullTimeDay(_ key: String) -> Bool {
        !isWeekend(key)
    }
}
