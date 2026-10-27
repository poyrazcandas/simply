import Foundation

enum HabitOrder {
    /// Move a habit into `targetCategory`, inserting before `overId` when provided,
    /// or appending when `overId` is nil.
    static func moveHabit(
        _ habits: [Habit],
        activeId: String,
        targetCategory: HabitCategory,
        overId: String? = nil
    ) -> [Habit] {
        guard let active = habits.first(where: { $0.id == activeId }) else { return habits }

        var grouped = Categories.groupHabitsByCategory(habits.filter { $0.id != activeId })
        var moved = active
        moved.category = targetCategory
        var targetList = grouped[targetCategory] ?? []

        if let overId {
            if let overIndex = targetList.firstIndex(where: { $0.id == overId }) {
                targetList.insert(moved, at: overIndex)
            } else {
                targetList.append(moved)
            }
        } else {
            targetList.append(moved)
        }

        grouped[targetCategory] = targetList
        return Categories.order.flatMap { grouped[$0] ?? [] }
    }
}
