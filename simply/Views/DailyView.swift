import SwiftUI

struct DailyView: View {
    @EnvironmentObject private var store: TrackerStore

    private var log: DailyLog { store.displayLog(for: store.selectedDateKey) }
    private var completedIds: Set<String> { Set(log.completedHabitIds) }
    private var grouped: [HabitCategory: [Habit]] { Categories.groupHabitsByCategory(store.habits) }
    private var fullTime: Bool { DailyProgress.isLogFullTime(log) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DateNavigator(
                date: store.selectedDateKey,
                todayKey: store.todayKey,
                saving: store.saving,
                savedFlash: store.savedFlash,
                streak: DailyProgress.computeCompleteDayCount(habits: store.habits, logs: store.logs),
                onDateChange: { store.changeDate(to: $0) }
            )

            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if Features.dailyProgress, !store.habits.isEmpty {
                            progressRow(width: geo.size.width)
                        }
                        habitRow(width: geo.size.width)
                    }
                    .padding(.bottom, 8)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .clipped()
            }

            if Features.dailyReflection {
                DailyReflectionCard(
                    highlight: log.highlight,
                    rating: log.rating,
                    onHighlight: { store.setHighlight($0) },
                    onRating: { store.setRating($0) }
                )
            }
        }
    }

    private func columnWidth(_ category: HabitCategory, totalWidth: CGFloat) -> CGFloat {
        let unit = (totalWidth - DailyGrid.spacing * 3) / DailyGrid.totalUnits
        return category == .dayActivities ? unit * DailyGrid.boosterRatio : unit
    }

    private func progressRow(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Progress")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
            HStack(alignment: .top, spacing: DailyGrid.spacing) {
                ForEach(Categories.order, id: \.self) { cat in
                    let progress = DailyProgress.getBlockProgress(
                        habits: store.habits,
                        category: cat,
                        completedIds: completedIds,
                        fullTime: fullTime
                    )
                    ProgressMiniCard(category: cat, progress: progress)
                        .frame(width: columnWidth(cat, totalWidth: width), alignment: .top)
                }
            }
        }
    }

    private func habitRow(width: CGFloat) -> some View {
        let wide = width >= 980
        return Group {
            if wide {
                HStack(alignment: .top, spacing: DailyGrid.spacing) {
                    ForEach(Categories.order, id: \.self) { cat in
                        blockColumn(cat)
                            .frame(width: columnWidth(cat, totalWidth: width), alignment: .top)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: DailyGrid.spacing) {
                    ForEach(Categories.order, id: \.self) { cat in
                        blockColumn(cat)
                    }
                }
            }
        }
    }

    private func blockColumn(_ category: HabitCategory) -> some View {
        let habits = grouped[category] ?? []
        let done = habits.filter { completedIds.contains($0.id) }.count
        let extraCompleteTodos = category == .dayActivities && Features.todoCalendar
        let extraPlanned = category == .night && Features.dailyProgress
        return HabitBlockCard(
            category: category,
            habits: habits,
            completedIds: completedIds,
            doneLabel: habits.isEmpty ? nil : "\(done)/\(habits.count)",
            showCompleteTodos: extraCompleteTodos,
            showPlannedNextDay: extraPlanned,
            twoColumn: category == .dayActivities,
            onToggle: { store.toggleHabit($0) }
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private enum DailyGrid {
    static let spacing: CGFloat = 12
    static let boosterRatio: CGFloat = 1.3
    static let totalUnits: CGFloat = 4.3
}

struct DateNavigator: View {
    var date: String
    var todayKey: String
    var saving: Bool
    var savedFlash: Bool
    var streak: Int
    var onDateChange: (String) -> Void

    @State private var calendarOpen = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily planner")
                    .font(.stoic( 11, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.primary.opacity(0.75))
                Button {
                    calendarOpen.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(AppTheme.primary)
                        Text(DateKeys.formatDisplayDate(date, today: todayKey))
                            .font(.stoic( 22, weight: .semibold))
                            .lineLimit(1)
                        if Features.dailyProgress {
                            Text("💪 \(streak)")
                                .font(.stoic( 13, weight: .semibold).monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.palette(.emerald).opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(AppTheme.palette(.emerald).opacity(0.4), lineWidth: 1)
                                )
                                .foregroundStyle(Color(red: 0.72, green: 0.96, blue: 0.82))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.secondary.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.primary.opacity(0.4), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $calendarOpen) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pick a day")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.mutedText)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { DateKeys.parseDateKey(date) },
                                set: {
                                    onDateChange(DateKeys.formatDateKey($0))
                                    calendarOpen = false
                                }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    }
                    .padding(12)
                    .frame(width: 320)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(saving ? "Saving…" : (savedFlash ? "Saved" : " "))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedText)
                        .frame(width: 56, alignment: .trailing)
                        .opacity(saving || savedFlash ? 1 : 0)
                    navButton("chevron.left") { onDateChange(DateKeys.addDays(date, -1)) }
                    Button("Today") { onDateChange(todayKey) }
                        .buttonStyle(.plain)
                        .font(.stoic( 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.primary.opacity(date == todayKey ? 0.12 : 0.22), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.primary.opacity(0.5), lineWidth: 2)
                        )
                        .disabled(date == todayKey)
                    navButton("chevron.right") { onDateChange(DateKeys.addDays(date, 1)) }
                }
                .padding(6)
                .background(AppTheme.muted.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .chromeCard()
    }

    private func navButton(_ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.stoic( 14, weight: .bold))
                .frame(width: 32, height: 32)
                .background(AppTheme.secondary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.primary.opacity(0.45), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

struct HabitBlockCard: View {
    var category: HabitCategory
    var habits: [Habit]
    var completedIds: Set<String>
    var doneLabel: String?
    var showCompleteTodos: Bool
    var showPlannedNextDay: Bool
    var twoColumn: Bool
    var onToggle: (String) -> Void

    private var accent: Color { AppTheme.blockAccent(category) }
    private var icon: String {
        switch category {
        case .morning: return "sun.max.fill"
        case .dayActivities: return "bolt.heart.fill"
        case .dayHabits: return "arrow.triangle.2.circlepath"
        case .night: return "moon.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .font(.stoic( 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text(Categories.labels[category] ?? category.rawValue)
                    .font(.stoic( 16, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                if let doneLabel {
                    Text(doneLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.mutedText)
                }
            }
            if showCompleteTodos {
                specialRow(
                    id: SpecialHabitID.completeTodos,
                    title: "Complete To-Do’s",
                    icon: "checklist"
                )
            }
            if showPlannedNextDay {
                specialRow(
                    id: SpecialHabitID.plannedNextDay,
                    title: SpecialHabitID.plannedNextDayTitle,
                    icon: "calendar"
                )
            }
            if habits.isEmpty {
                Text(dailyEmptyMessage)
                    .font(.callout)
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(AppTheme.border)
                    )
            } else if twoColumn {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(habits) { habit in
                        HabitCheckRow(habit: habit, checked: completedIds.contains(habit.id), onToggle: onToggle)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(habits) { habit in
                        HabitCheckRow(habit: habit, checked: completedIds.contains(habit.id), onToggle: onToggle)
                    }
                }
            }
        }
        .timeBlockCard(accent)
    }

    private var dailyEmptyMessage: String {
        switch category {
        case .morning: return "No morning habits yet."
        case .dayActivities: return "No day boosters yet."
        case .dayHabits: return "No day habits yet. Add them in the Habits tab."
        case .night: return "No night habits yet."
        }
    }

    private func specialRow(id: String, title: String, icon: String) -> some View {
        let checked = completedIds.contains(id)
        let color = checked ? AppTheme.palette(.emerald) : Color.red
        return Button {
            onToggle(id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(color)
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.stoic( 13, weight: .semibold))
                    .foregroundStyle(checked ? Color(red: 0.72, green: 0.96, blue: 0.82) : Color(red: 0.98, green: 0.75, blue: 0.75))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }
}

struct HabitCheckRow: View {
    var habit: Habit
    var checked: Bool
    var onToggle: (String) -> Void

    var body: some View {
        Button {
            onToggle(habit.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.stoic( 16, weight: .semibold))
                    .foregroundStyle(checked ? AppTheme.primary : AppTheme.mutedText)
                Text(habit.title)
                    .font(.stoic( 15, weight: .medium))
                    .strikethrough(checked, color: AppTheme.mutedText.opacity(0.5))
                    .foregroundStyle(checked ? AppTheme.mutedText : AppTheme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(checked ? AppTheme.primary.opacity(0.16) : AppTheme.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(checked ? AppTheme.primary.opacity(0.5) : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProgressMiniCard: View {
    var category: HabitCategory
    var progress: DailyProgress.BlockProgress

    private var accent: Color {
        if progress.isComplete && progress.hasHabits { return AppTheme.palette(.emerald) }
        if category == .dayActivities, progress.todosChecked == false { return .red }
        if category == .night, progress.plannedNextDayChecked == false { return .red }
        return AppTheme.blockAccent(category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Categories.labels[category] ?? "")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)
                Spacer()
                if progress.hasHabits {
                    Text(progress.isComplete ? "\(progress.display) · Done" : "\(progress.display) · \(progress.percent)%")
                        .font(.caption.monospacedDigit())
                } else {
                    Text("—").foregroundStyle(AppTheme.mutedText).font(.caption)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.muted)
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * CGFloat(progress.hasHabits ? progress.percent : 0) / 100)
                }
            }
            .frame(height: 6)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [accent.opacity(0.18), AppTheme.card], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.55), lineWidth: 2)
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct DailyReflectionCard: View {
    var highlight: String
    var rating: Int
    var onHighlight: (String) -> Void
    var onRating: (Int) -> Void

    private var amber: Color { AppTheme.palette(.amber) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(amber)
                    .frame(width: 28, height: 28)
                    .background(amber.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(amber.opacity(0.45), lineWidth: 1)
                    )
                Text("Daily Reflection")
                    .font(.stoic(16, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: Binding(get: { highlight }, set: onHighlight))
                        .font(.body)
                        .foregroundStyle(AppTheme.text)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                    if highlight.isEmpty {
                        Text("Best moment today…")
                            .foregroundStyle(AppTheme.mutedText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 110)
                .background(AppTheme.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(amber.opacity(0.35), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Day Rating")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Text("\(rating)")
                            .font(.stoic(24, weight: .semibold))
                            .foregroundStyle(amber)
                        + Text("/10")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(rating) },
                            set: { onRating(Int($0.rounded())) }
                        ),
                        in: 1...10,
                        step: 1
                    )
                    .tint(amber)
                    HStack {
                        Text("Rough")
                        Spacer()
                        Text("Amazing")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                }
                .padding(12)
                .frame(width: 260)
                .background(AppTheme.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.8), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [amber.opacity(0.16), AppTheme.card, AppTheme.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(amber.opacity(0.45), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}
