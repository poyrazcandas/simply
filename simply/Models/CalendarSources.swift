import Foundation

enum CalendarSources {
    static let importColorRotation: [PaletteColor] = [
        .cyan, .emerald, .orange, .fuchsia, .amber, .rose, .sky, .violet,
    ]

    static func normalize(_ sources: [CalendarSource]?) -> [CalendarSource] {
        guard let sources else { return [] }
        return sources.compactMap { s in
            guard !s.id.isEmpty else { return nil }
            let name = s.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return CalendarSource(
                id: s.id,
                name: name.isEmpty ? "Imported calendar" : name,
                color: s.color,
                enabled: s.enabled,
                events: s.events.compactMap(normalizeEvent),
                importedAt: s.importedAt.isEmpty ? ISO8601DateFormatter().string(from: Date()) : s.importedAt
            )
        }
    }

    private static let dateRegex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
    private static let timeRegex = try! NSRegularExpression(pattern: "^\\d{2}:\\d{2}$")

    private static func matches(_ regex: NSRegularExpression, _ value: String) -> Bool {
        regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    private static func normalizeEvent(_ raw: ImportedCalendarEvent) -> ImportedCalendarEvent? {
        let title = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let startSlice = String(raw.startDate.prefix(10))
        guard matches(dateRegex, startSlice) else { return nil }
        var endDate = matches(dateRegex, String(raw.endDate.prefix(10))) ? String(raw.endDate.prefix(10)) : startSlice
        if endDate < startSlice { endDate = startSlice }
        let allDay = raw.allDay
        let startTime = (!allDay && matches(timeRegex, raw.startTime ?? "")) ? raw.startTime : nil
        let endTime = (!allDay && matches(timeRegex, raw.endTime ?? "")) ? raw.endTime : nil
        return ImportedCalendarEvent(
            id: raw.id.isEmpty ? UUID().uuidString : raw.id,
            title: title,
            startDate: startSlice,
            endDate: endDate,
            allDay: allDay || (startTime == nil && endTime == nil),
            startTime: startTime,
            endTime: endTime,
            description: raw.description
        )
    }
}
