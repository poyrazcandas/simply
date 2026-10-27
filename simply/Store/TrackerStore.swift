import Foundation
import Combine
import AppKit

@MainActor
final class TrackerStore: ObservableObject {
    @Published private(set) var data: TrackerData = .empty
    @Published var selectedTab: AppTab = .daily
    @Published var selectedDateKey: String = DateKeys.formatDateKey(Date())
    @Published var todayKey: String = DateKeys.formatDateKey(Date())
    @Published var saving = false
    @Published var savedFlash = false
    @Published var loaded = false
    @Published var todoNavigateDateKey: String?

    private let ioQueue = DispatchQueue(label: "simply.tracker.io")
    private var highlightWorkItem: DispatchWorkItem?
    private var savedFlashWorkItem: DispatchWorkItem?
    private var midnightTimer: Timer?
    private let fileURL: URL
    private let tempURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("simply", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("tracker.json")
        tempURL = dir.appendingPathComponent("tracker.json.tmp")
        loadFromDisk()
        startTodayTracking()
    }

    var habits: [Habit] { data.habits }
    var logs: [String: DailyLog] { data.logs }
    var todos: [TodoItem] { data.todos }
    var todoTags: [TodoTag] { data.todoTags }
    var calendarSources: [CalendarSource] { data.calendarSources }

    func log(for dateKey: String) -> DailyLog {
        data.logs[dateKey] ?? DailyLog.blank(date: dateKey)
    }

    func visibleCompletedIds(for dateKey: String) -> Set<String> {
        let active = Set(data.habits.map(\.id))
        let raw = log(for: dateKey).completedHabitIds
        return Set(raw.filter { id in
            active.contains(id)
                || (Features.todoCalendar && id == SpecialHabitID.completeTodos)
                || (Features.dailyProgress && id == SpecialHabitID.plannedNextDay)
        })
    }

    func displayLog(for dateKey: String) -> DailyLog {
        var log = self.log(for: dateKey)
        log.date = dateKey
        log.completedHabitIds = Array(visibleCompletedIds(for: dateKey))
        log.rating = DailyLog.clampRating(log.rating)
        log.fullTime = DateKeys.isFullTimeDay(dateKey)
        return log
    }

    func changeDate(to next: String) {
        flushPendingLogSave()
        selectedDateKey = next
    }

    func shiftDate(_ delta: Int) {
        changeDate(to: DateKeys.addDays(selectedDateKey, delta))
    }

    func goToToday() {
        changeDate(to: todayKey)
    }

    func toggleHabit(_ habitId: String, dateKey: String? = nil) {
        let key = dateKey ?? selectedDateKey
        mutateLog(dateKey: key, immediate: true) { log in
            var ids = Set(log.completedHabitIds)
            if ids.contains(habitId) {
                ids.remove(habitId)
            } else {
                ids.insert(habitId)
            }
            log.completedHabitIds = Array(ids)
        }
    }

    func setHighlight(_ text: String, dateKey: String? = nil) {
        let key = dateKey ?? selectedDateKey
        mutateLog(dateKey: key, immediate: false) { log in
            log.highlight = text
        }
    }

    func setRating(_ rating: Int, dateKey: String? = nil) {
        let key = dateKey ?? selectedDateKey
        mutateLog(dateKey: key, immediate: true) { log in
            log.rating = DailyLog.clampRating(rating)
        }
    }

    func saveHabits(_ habits: [Habit]) {
        data.habits = Categories.normalizeHabits(habits)
        persist()
    }

    func addHabit(title: String, category: HabitCategory) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var habits = data.habits
        habits.append(Habit(id: UUID().uuidString, title: trimmed, category: category))
        saveHabits(habits)
    }

    func deleteHabit(id: String) {
        saveHabits(data.habits.filter { $0.id != id })
    }

    func updateHabit(id: String, title: String, category: HabitCategory) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveHabits(data.habits.map { h in
            h.id == id ? Habit(id: h.id, title: trimmed, category: category) : h
        })
    }

    func moveHabit(activeId: String, targetCategory: HabitCategory, overId: String?) {
        saveHabits(HabitOrder.moveHabit(data.habits, activeId: activeId, targetCategory: targetCategory, overId: overId))
    }

    func saveTodos(_ todos: [TodoItem], tags: [TodoTag]? = nil) {
        let normalizedTags = TodoTags.normalizeTodoTags(tags ?? data.todoTags)
        data.todoTags = normalizedTags
        data.todos = TodoTags.stripTodoTagIds(Todos.normalizeTodos(todos), tags: normalizedTags)
        persist()
    }

    func saveCalendarSources(_ sources: [CalendarSource]) {
        data.calendarSources = CalendarSources.normalize(sources)
        persist()
    }

    func openTodoTabForToday() {
        selectedTab = .todos
        todoNavigateDateKey = todayKey
    }

    func flushPendingLogSave() {
        highlightWorkItem?.cancel()
        highlightWorkItem = nil
        persist()
    }

    func refreshToday() {
        let next = DateKeys.formatDateKey(Date())
        if next != todayKey {
            let previous = todayKey
            todayKey = next
            if Features.todoCalendar {
                todoNavigateDateKey = next
            }
            _ = previous
        }
    }

    private func mutateLog(dateKey: String, immediate: Bool, update: (inout DailyLog) -> Void) {
        var log = displayLog(for: dateKey)
        update(&log)
        log.date = dateKey
        log.rating = DailyLog.clampRating(log.rating)
        log.fullTime = DateKeys.isFullTimeDay(dateKey)
        data.logs[dateKey] = log
        if immediate {
            persist()
        } else {
            scheduleDebouncedSave()
        }
    }

    private func scheduleDebouncedSave() {
        highlightWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.persist()
            }
        }
        highlightWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    private func persist() {
        saving = true
        let snapshot = normalize(data)
        data = snapshot
        ioQueue.async { [fileURL, tempURL] in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let payload = try encoder.encode(snapshot)
                try payload.write(to: tempURL, options: [])
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
                } else {
                    try FileManager.default.moveItem(at: tempURL, to: fileURL)
                }
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                NSLog("simply: failed to save tracker.json: \(error)")
            }
            DispatchQueue.main.async { [weak self] in
                self?.saving = false
                self?.flashSaved()
            }
        }
    }

    private func flashSaved() {
        savedFlash = true
        savedFlashWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.savedFlash = false
        }
        savedFlashWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func loadFromDisk() {
        ioQueue.async { [fileURL] in
            let loaded: TrackerData
            if let raw = try? Data(contentsOf: fileURL), !raw.isEmpty,
               let decoded = try? JSONDecoder().decode(TrackerData.self, from: raw)
            {
                loaded = decoded
            } else if let migrated = Self.migrateFromWebApp() {
                loaded = migrated
            } else {
                loaded = .empty
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.data = self.normalize(loaded)
                if !FileManager.default.fileExists(atPath: self.fileURL.path) {
                    self.persist()
                }
                self.loaded = true
            }
        }
    }

    nonisolated private static func migrateFromWebApp() -> TrackerData? {
        let candidate = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/ultimate-program/data/tracker.json")
        guard let raw = try? Data(contentsOf: candidate), !raw.isEmpty,
              let decoded = try? JSONDecoder().decode(TrackerData.self, from: raw)
        else { return nil }
        return decoded
    }

    private func normalize(_ raw: TrackerData) -> TrackerData {
        var next = raw
        next.habits = Categories.normalizeHabits(raw.habits)
        next.todoTags = TodoTags.normalizeTodoTags(raw.todoTags)
        next.todos = TodoTags.stripTodoTagIds(Todos.normalizeTodos(raw.todos), tags: next.todoTags)
        next.calendarSources = CalendarSources.normalize(raw.calendarSources)
        var logs: [String: DailyLog] = [:]
        for (key, log) in raw.logs {
            var copy = log
            copy.date = key
            copy.rating = DailyLog.clampRating(log.rating)
            copy.fullTime = DateKeys.isFullTimeDay(key)
            logs[key] = copy
        }
        next.logs = logs
        return next
    }

    private func startTodayTracking() {
        scheduleMidnight()
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshToday() }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshToday() }
        }
    }

    private func scheduleMidnight() {
        midnightTimer?.invalidate()
        let interval = DateKeys.msUntilNextLocalMidnight()
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshToday()
                self?.scheduleMidnight()
            }
        }
        midnightTimer?.tolerance = 1
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case daily, habits, insights, todos
    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .habits: return "Habits"
        case .insights: return "Insights"
        case .todos: return "To-Do/Calendar"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: return "calendar"
        case .habits: return "list.bullet.rectangle"
        case .insights: return "chart.bar"
        case .todos: return "checklist"
        }
    }
}
