import Foundation

enum ICSParser {
    static func parse(text: String, sourceId: String) -> [ImportedCalendarEvent] {
        let unfolded = unfold(text)
        let blocks = unfolded.components(separatedBy: "BEGIN:VEVENT").dropFirst()
        var events: [ImportedCalendarEvent] = []

        for (index, block) in blocks.enumerated() {
            let summary = readProperty(block, "SUMMARY") ?? "Untitled event"
            guard let dtStartRaw = readProperty(block, "DTSTART") else { continue }
            let start = parseIcsDateTime(dtStartRaw)
            let end = readProperty(block, "DTEND").map(parseIcsDateTime) ?? start
            let uid = readProperty(block, "UID")
            let description = readProperty(block, "DESCRIPTION")

            var endDate = end.dateKey
            if start.allDay && end.dateKey > start.dateKey {
                endDate = DateKeys.addDays(end.dateKey, -1)
            }

            events.append(
                ImportedCalendarEvent(
                    id: uid ?? "\(sourceId)-\(index)-\(start.dateKey)",
                    title: summary.replacingOccurrences(of: "\\n", with: " ").replacingOccurrences(of: "\\,", with: ","),
                    startDate: start.dateKey,
                    endDate: endDate,
                    allDay: start.allDay,
                    startTime: start.time,
                    endTime: end.time,
                    description: description?.replacingOccurrences(of: "\\n", with: "\n")
                )
            )
        }
        return events
    }

    private static func unfold(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
    }

    private struct ICSDateTime {
        var dateKey: String
        var time: String?
        var allDay: Bool
    }

    private static func parseIcsDateTime(_ raw: String) -> ICSDateTime {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count == 8, value.allSatisfy(\.isNumber) {
            let y = value.prefix(4)
            let m = value.dropFirst(4).prefix(2)
            let d = value.dropFirst(6).prefix(2)
            return ICSDateTime(dateKey: "\(y)-\(m)-\(d)", time: nil, allDay: true)
        }
        let pattern = #"^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let y = Range(match.range(at: 1), in: value),
           let m = Range(match.range(at: 2), in: value),
           let d = Range(match.range(at: 3), in: value),
           let hh = Range(match.range(at: 4), in: value),
           let mm = Range(match.range(at: 5), in: value)
        {
            return ICSDateTime(
                dateKey: "\(value[y])-\(value[m])-\(value[d])",
                time: "\(value[hh]):\(value[mm])",
                allDay: false
            )
        }
        return ICSDateTime(dateKey: DateKeys.formatDateKey(Date()), time: nil, allDay: true)
    }

    private static func readProperty(_ block: String, _ name: String) -> String? {
        let pattern = "^\(name)[^:]*:(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]),
              let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let range = Range(match.range(at: 1), in: block)
        else { return nil }
        return String(block[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
