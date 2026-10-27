import Foundation

enum TodoTags {
    static let colors: [PaletteColor] = PaletteColor.allCases

    struct DayTagIndicators {
        var colors: [PaletteColor]
        var overflow: Int
    }

    static func normalizeTodoTags(_ tags: [TodoTag]) -> [TodoTag] {
        var seen = Set<String>()
        var result: [TodoTag] = []
        for raw in tags {
            let name = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.id.isEmpty, !name.isEmpty, !seen.contains(raw.id) else { continue }
            seen.insert(raw.id)
            result.append(TodoTag(id: raw.id, name: name, color: raw.color))
        }
        return result
    }

    static func stripTodoTagIds(_ todos: [TodoItem], tags: [TodoTag]) -> [TodoItem] {
        let valid = Set(tags.map(\.id))
        return todos.map { todo in
            var next = todo
            next.tagIds = todo.tagIds.filter { valid.contains($0) }
            return next
        }
    }

    static func removeTagFromTodos(_ todos: [TodoItem], tagId: String) -> [TodoItem] {
        todos.map { todo in
            var next = todo
            next.tagIds = todo.tagIds.filter { $0 != tagId }
            return next
        }
    }

    static func resolveTags(tagIds: [String], catalog: [TodoTag]) -> [TodoTag] {
        let map = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        return tagIds.compactMap { map[$0] }
    }

    static func getTagIndicatorsForDate(dateKey: String, todos: [TodoItem], catalog: [TodoTag]) -> DayTagIndicators {
        let tagById = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        var colors: [PaletteColor] = []
        var seen = Set<PaletteColor>()
        for todo in todos where Todos.todoVisibleOnDate(todo, viewDateKey: dateKey) {
            for tagId in todo.tagIds {
                guard let tag = tagById[tagId], !seen.contains(tag.color) else { continue }
                seen.insert(tag.color)
                colors.append(tag.color)
            }
        }
        return DayTagIndicators(
            colors: Array(colors.prefix(3)),
            overflow: max(0, colors.count - 3)
        )
    }
}
