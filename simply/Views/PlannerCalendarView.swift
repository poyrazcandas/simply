import SwiftUI
import UniformTypeIdentifiers

struct PlannerCalendarView: View {
    @EnvironmentObject private var store: TrackerStore
    @State private var viewMode: CalMode = .week
    @State private var focusDate = DateKeys.formatDateKey(Date())
    @State private var includeTodos = true
    @State private var importing = false
    @State private var editor: TimedEditor?
    @State private var detail: CalendarDisplayEntry?
    @State private var dragPreview: DragPreview?
    @State private var nowMinutes = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())

    enum CalMode { case week, month }

    struct TimedEditor: Identifiable {
        var id: String { todoId ?? "new-\(dateKey)-\(start)" }
        var todoId: String?
        var dateKey: String
        var title: String
        var start: String
        var end: String
        var tagIds: [String]
    }

    struct DragPreview {
        var dateKey: String
        var startMinutes: Int
        var height: CGFloat
    }

    private let dayWidth: CGFloat = 168
    private let gutterWidth: CGFloat = 64
    private let stripBuffer = 28

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            sidebar
            main
        }
        .onAppear { tickNow() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in tickNow() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "ics") ?? .data]) { result in
            if case .success(let url) = result { importICS(url) }
        }
        .popover(item: $editor) { item in
            timedEditor(item)
        }
        .popover(item: $detail) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title).font(.headline)
                if let subtitle = entry.subtitle { Text(subtitle).foregroundStyle(AppTheme.mutedText) }
                if let source = entry.sourceName { Text(source).font(.caption).foregroundStyle(AppTheme.mutedText) }
            }
            .padding(14)
            .frame(minWidth: 200)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("To-Do (integrated)", isOn: $includeTodos)
            Divider()
            Text("Calendars").font(.headline)
            ForEach(store.calendarSources) { source in
                HStack {
                    Toggle(isOn: Binding(
                        get: { source.enabled },
                        set: { enabled in
                            store.saveCalendarSources(store.calendarSources.map {
                                $0.id == source.id ? CalendarSource(id: $0.id, name: $0.name, color: $0.color, enabled: enabled, events: $0.events, importedAt: $0.importedAt) : $0
                            })
                        }
                    )) {
                        HStack {
                            Circle().fill(AppTheme.palette(source.color)).frame(width: 8, height: 8)
                            Text(source.name).lineLimit(1)
                        }
                    }
                    .toggleStyle(.checkbox)
                    Spacer()
                    Button(role: .destructive) {
                        store.saveCalendarSources(store.calendarSources.filter { $0.id != source.id })
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                importing = true
            } label: {
                Label("Upload .ics", systemImage: "square.and.arrow.up")
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 230)
        .chromeCard()
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 0) {
                    modeChip("7-day", .week)
                    modeChip("Month", .month)
                }
                .padding(3)
                .background(AppTheme.muted.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                Spacer()
                Button { focusDate = DateKeys.addDays(focusDate, viewMode == .week ? -7 : -30) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Button("Today") { focusDate = store.todayKey }
                Button { focusDate = DateKeys.addDays(focusDate, viewMode == .week ? 7 : 30) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            if viewMode == .week {
                weekStrip
            } else {
                monthGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modeChip(_ title: String, _ mode: CalMode) -> some View {
        Button(title) { viewMode = mode }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(viewMode == mode ? AppTheme.primary : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(viewMode == mode ? Color.white : AppTheme.mutedText)
    }

    private var weekStrip: some View {
        let start = DateKeys.addDays(focusDate, -stripBuffer)
        let keys = (0..<(stripBuffer * 2 + 7)).map { DateKeys.addDays(start, $0) }
        let gridHeight = CGFloat(24) * CalendarDisplay.hourHeight
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    timeGutter(gridHeight: gridHeight)
                    ForEach(keys, id: \.self) { key in
                        dayColumn(key, gridHeight: gridHeight)
                            .frame(width: dayWidth)
                            .id(key)
                    }
                }
            }
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(focusDate, anchor: .leading)
                }
            }
            .onChange(of: focusDate) { _, new in
                proxy.scrollTo(new, anchor: .leading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
    }

    private func timeGutter(gridHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 86)
            ForEach(CalendarDisplay.hours, id: \.self) { hour in
                Text(CalendarDisplay.formatHourLabel(hour))
                    .font(.stoic( 10))
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(width: gutterWidth, height: CalendarDisplay.hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 6)
            }
        }
        .frame(width: gutterWidth, height: 86 + gridHeight, alignment: .top)
    }

    private func dayColumn(_ dateKey: String, gridHeight: CGFloat) -> some View {
        let entries = CalendarDisplay.getAllEntries(
            todos: store.todos,
            sources: store.calendarSources,
            dateKey: dateKey,
            includeTodos: includeTodos
        )
        let split = CalendarDisplay.splitEntries(entries)
        let isToday = dateKey == store.todayKey
        let date = DateKeys.parseDateKey(dateKey)
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.stoic( 10, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.stoic( 16, weight: .bold))
                    .foregroundStyle(isToday ? .white : AppTheme.text)
                    .frame(width: 30, height: 30)
                    .background(isToday ? Color.red : Color.clear, in: Circle())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(AppTheme.background)
            .zIndex(20)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    chipRow(split.weekMonth)
                    chipRow(split.allDay)
                    timedGrid(dateKey: dateKey, entries: split.timed, gridHeight: gridHeight, isToday: isToday)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
        .overlay(Rectangle().frame(width: 1).foregroundStyle(AppTheme.border.opacity(0.5)), alignment: .trailing)
    }

    private func chipRow(_ entries: [CalendarDisplayEntry]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(entries) { entry in
                Text(entry.title)
                    .font(.stoic( 10, weight: .semibold))
                    .strikethrough(entry.completed == true)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.palette(entry.color).opacity(entry.completed == true ? 0.35 : 0.85), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppTheme.palette(entry.color).opacity(0.7)))
                    .onTapGesture { detail = entry }
            }
        }
        .frame(minHeight: 18)
    }

    private func timedGrid(dateKey: String, entries: [CalendarDisplayEntry], gridHeight: CGFloat, isToday: Bool) -> some View {
        let nowY = CalendarDisplay.timeMinutesToGridY(nowMinutes)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(CalendarDisplay.hours, id: \.self) { _ in
                    Rectangle()
                        .fill(AppTheme.border.opacity(0.25))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity, maxHeight: CalendarDisplay.hourHeight, alignment: .top)
                }
            }
            .frame(height: gridHeight)

            ForEach(entries) { entry in
                let top = CalendarDisplay.entryTopOffset(entry)
                let height = CalendarDisplay.entryHeight(entry: entry, gridHeight: gridHeight)
                timedBlock(entry, dateKey: dateKey, height: height)
                    .offset(y: top)
            }

            if let dragPreview, dragPreview.dateKey == dateKey {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.palette(.violet).opacity(0.35))
                    .overlay(Text("Moving…").font(.caption2).padding(4), alignment: .topLeading)
                    .frame(height: dragPreview.height)
                    .offset(y: CalendarDisplay.timeMinutesToGridY(dragPreview.startMinutes))
            }

            if isToday, nowY >= 0, nowY <= gridHeight {
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 2)
                    .offset(y: nowY)
            }
        }
        .frame(height: gridHeight, alignment: .top)
        .clipped(antialiased: false)
        .contentShape(Rectangle())
        .onTapGesture { location in
            let minutes = CalendarDisplay.gridYToTimeMinutes(location.y)
            let start = Todos.formatTimeFromMinutes(minutes)
            let end = Todos.addMinutesToTime(start, Todos.defaultTimedDurationMinutes)
            editor = TimedEditor(todoId: nil, dateKey: dateKey, title: "New event", start: start, end: end, tagIds: [])
        }
    }

    private func timedBlock(_ entry: CalendarDisplayEntry, dateKey: String, height: CGFloat) -> some View {
        let draggable = entry.kind == .todoTimed && entry.todoId != nil
        return Text(entry.title)
            .font(.stoic( 11, weight: .semibold))
            .strikethrough(entry.completed == true)
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background(AppTheme.palette(entry.color).opacity(entry.completed == true ? 0.35 : 0.85), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.palette(entry.color)))
            .opacity(entry.completed == true ? 0.7 : 1)
            .highPriorityGesture(TapGesture().onEnded {
                if draggable, let todoId = entry.todoId, let todo = store.todos.first(where: { $0.id == todoId }) {
                    editor = TimedEditor(
                        todoId: todo.id,
                        dateKey: dateKey,
                        title: todo.title,
                        start: todo.time ?? "09:00",
                        end: Todos.getTodoEndTime(todo),
                        tagIds: todo.tagIds
                    )
                } else {
                    detail = entry
                }
            })
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard draggable else { return }
                        let start = CalendarDisplay.gridYToTimeMinutes(CalendarDisplay.entryTopOffset(entry) + value.translation.height)
                        dragPreview = DragPreview(dateKey: dateKey, startMinutes: start, height: height)
                    }
                    .onEnded { value in
                        defer { dragPreview = nil }
                        guard draggable, let todoId = entry.todoId else { return }
                        let startMinutes = CalendarDisplay.gridYToTimeMinutes(CalendarDisplay.entryTopOffset(entry) + value.translation.height)
                        let duration = CalendarDisplay.entryDurationMinutes(entry)
                        let dayShift = Int((value.translation.width / dayWidth).rounded())
                        let newDate = DateKeys.addDays(dateKey, dayShift)
                        let start = Todos.formatTimeFromMinutes(startMinutes)
                        let end = Todos.addMinutesToTime(start, duration)
                        store.saveTodos(store.todos.map { todo in
                            guard todo.id == todoId else { return todo }
                            var next = todo
                            next.anchor = newDate
                            next.dueDate = newDate
                            next.time = start
                            next.endTime = end
                            return next
                        })
                    }
            )
    }

    private var monthGrid: some View {
        let monthDate = DateKeys.parseDateKey(focusDate)
        let year = Calendar.current.component(.year, from: monthDate)
        let month = Calendar.current.component(.month, from: monthDate)
        let days = CalendarDisplay.getMonthGridDays(year: year, month: month)
        return VStack(spacing: 6) {
            HStack {
                ForEach(CalendarDisplay.weekdayHeaders, id: \.self) { h in
                    Text(h).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { key in
                    let inMonth = String(key.prefix(7)) == String(focusDate.prefix(7))
                    let entries = CalendarDisplay.getAllEntries(
                        todos: store.todos,
                        sources: store.calendarSources,
                        dateKey: key,
                        includeTodos: includeTodos
                    )
                    Button {
                        focusDate = key
                        viewMode = .week
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Calendar.current.component(.day, from: DateKeys.parseDateKey(key)))")
                                .font(.stoic( 12, weight: .semibold))
                                .foregroundStyle(key == store.todayKey ? .white : (inMonth ? AppTheme.text : AppTheme.mutedText.opacity(0.4)))
                                .frame(width: 22, height: 22)
                                .background(key == store.todayKey ? AppTheme.palette(.emerald) : Color.clear, in: Circle())
                            ForEach(entries.prefix(3)) { entry in
                                Text(entry.title)
                                    .font(.stoic( 9))
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .background(AppTheme.palette(entry.color).opacity(0.8), in: Capsule())
                            }
                            if entries.count > 3 {
                                Text("+\(entries.count - 3)").font(.stoic( 9)).foregroundStyle(AppTheme.mutedText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func timedEditor(_ item: TimedEditor) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: Binding(get: { item.title }, set: { editor?.title = $0 }))
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Start", text: Binding(get: { item.start }, set: { editor?.start = $0 }))
                TextField("End", text: Binding(get: { item.end }, set: { editor?.end = $0 }))
            }
            HStack {
                ForEach(store.todoTags) { tag in
                    Button {
                        var ids = Set(item.tagIds)
                        if ids.contains(tag.id) { ids.remove(tag.id) } else { ids.insert(tag.id) }
                        editor?.tagIds = Array(ids)
                    } label: {
                        Text(tag.name)
                            .font(.caption)
                            .padding(4)
                            .background(AppTheme.palette(tag.color).opacity(item.tagIds.contains(tag.id) ? 0.4 : 0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Button("Save") { saveEditor(item) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel") { editor = nil }
                    .keyboardShortcut(.cancelAction)
                if item.todoId != nil {
                    Spacer()
                    Button("Delete", role: .destructive) {
                        if let id = item.todoId {
                            store.saveTodos(store.todos.filter { $0.id != id })
                        }
                        editor = nil
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func saveEditor(_ item: TimedEditor) {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New event" : item.title
        let start = String(item.start.prefix(5))
        let end = Todos.normalizeTimedEndTime(startTime: start, endTime: item.end)
        if let id = item.todoId {
            store.saveTodos(store.todos.map { todo in
                guard todo.id == id else { return todo }
                var next = todo
                next.title = title
                next.anchor = item.dateKey
                next.dueDate = item.dateKey
                next.time = start
                next.endTime = end
                next.tagIds = item.tagIds
                next.scope = .timed
                return next
            })
        } else {
            let todo = TodoItem(
                id: UUID().uuidString,
                title: title,
                completed: false,
                scope: .timed,
                anchor: item.dateKey,
                dueDate: item.dateKey,
                time: start,
                endTime: end,
                tagIds: item.tagIds,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            store.saveTodos(store.todos + [todo])
        }
        editor = nil
    }

    private func importICS(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let sourceId = UUID().uuidString
        let events = ICSParser.parse(text: text, sourceId: sourceId)
        let color = CalendarSources.importColorRotation[store.calendarSources.count % CalendarSources.importColorRotation.count]
        let source = CalendarSource(
            id: sourceId,
            name: url.deletingPathExtension().lastPathComponent,
            color: color,
            enabled: true,
            events: events,
            importedAt: ISO8601DateFormatter().string(from: Date())
        )
        store.saveCalendarSources(store.calendarSources + [source])
    }

    private func tickNow() {
        let now = Date()
        nowMinutes = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
    }
}
