import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var store: TrackerStore
    @FocusState private var focusedTab: AppTab?

    private var visibleTabs: [AppTab] {
        var tabs: [AppTab] = [.daily, .habits, .insights]
        if Features.todoCalendar {
            tabs.insert(.todos, at: 0)
        }
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.border)
            Group {
                if !store.loaded {
                    VStack {
                        Spacer()
                        Text("Loading your planner…")
                            .foregroundStyle(AppTheme.mutedText)
                        Spacer()
                    }
                } else {
                    tabBody
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.text)
        .fontDesign(.serif)
        .navigationTitle("simply — Daily planner & habit tracker")
        .focusEffectDisabled()
        .onAppear { focusedTab = store.selectedTab }
        .onChange(of: store.selectedTab) { _, tab in
            focusedTab = tab
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image("SimplyLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
                Text("simply.")
                    .font(AppFonts.wordmark(34))
                    .tracking(0.6)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if Features.todoCalendar {
                TodoNotificationBar(
                    counts: Todos.getOpenTodoCountsForDate(store.todos, viewDateKey: store.todayKey)
                ) {
                    store.openTodoTabForToday()
                }
            }
            tabBar
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(visibleTabs) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(AppTheme.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .focusEffectDisabled()
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let selected = store.selectedTab == tab
        return Button {
            store.selectedTab = tab
            focusedTab = tab
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.stoic( 14, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? AppTheme.text : AppTheme.mutedText)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? AppTheme.primary.opacity(0.32) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? AppTheme.primary : Color.clear, lineWidth: 2)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($focusedTab, equals: tab)
        .focusEffectDisabled()
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .animation(.easeInOut(duration: 0.15), value: store.selectedTab)
    }

    @ViewBuilder
    private var tabBody: some View {
        switch store.selectedTab {
        case .daily:
            DailyView()
                .padding(20)
        case .habits:
            ScrollView {
                HabitManagerView()
                    .padding(20)
            }
        case .insights:
            ScrollView {
                InsightsView()
                    .padding(20)
            }
        case .todos:
            if Features.todoCalendar {
                TodoCalendarView()
                    .padding(20)
            } else {
                DailyView().padding(20)
            }
        }
    }
}

struct TodoNotificationBar: View {
    var counts: Todos.OpenCounts
    var onClick: () -> Void

    private var total: Int { counts.timed + counts.day + counts.week + counts.month }

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundStyle((total > 0 || counts.pastDue > 0) ? AppTheme.palette(.violet) : AppTheme.mutedText)
                Text("Today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.mutedText)
                countChip("T", counts.timed, AppTheme.palette(.violet))
                countChip("D", counts.day, AppTheme.palette(.sky))
                countChip("W", counts.week, AppTheme.palette(.amber))
                countChip("M", counts.month, AppTheme.palette(.emerald))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 2)
            )
            .overlay(alignment: .bottomTrailing) {
                Text(total > 99 ? "99+" : "\(total)")
                    .font(.stoic( 10, weight: .bold))
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(total > 0 ? Color.gray : AppTheme.mutedText.opacity(0.4), in: Capsule())
                    .offset(x: 6, y: 6)
            }
            .overlay(alignment: .topTrailing) {
                if counts.pastDue > 0 {
                    Text(counts.pastDue > 99 ? "99+" : "\(counts.pastDue)")
                        .font(.stoic( 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.red, in: Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
    }

    private func countChip(_ short: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(short)
                .font(.stoic( 9, weight: .semibold))
            Text("\(value)")
                .font(.stoic( 12, weight: .bold).monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.4), lineWidth: 1.5)
        )
    }
}
