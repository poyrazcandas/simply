import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: TrackerStore

    private var payload: InsightsPayload {
        Insights.compute(store.data, today: store.todayKey)
    }

    var body: some View {
        let data = payload
        let maxBlock = max(data.timeBlockImpacts.compactMap(\.avgRating).max() ?? 1, 1)
        let perfectRate = data.totalLoggedDays > 0
            ? Int(round(Double(data.perfectDayCount) / Double(data.totalLoggedDays) * 100))
            : 0

        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Insights & Analytics", systemImage: "chart.bar")
                    .font(.stoic( 24, weight: .semibold))
                Text("Based on \(data.totalLoggedDays) logged day\(data.totalLoggedDays == 1 ? "" : "s") with ratings.")
                    .foregroundStyle(AppTheme.mutedText)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Energy & Routine Correlations", systemImage: "bolt.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.palette(.amber))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(data.timeBlockImpacts) { block in
                        timeBlockCard(block, maxBlock: maxBlock)
                    }
                }
                impactTable(data.habitImpacts)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Habit Health", systemImage: "flame.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.orange)
                if Features.dailyProgress {
                    perfectDaysCard(data, perfectRate: perfectRate)
                }
                streaksTable(data.habitStreaks)
            }
        }
        .frame(maxWidth: 1100, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeBlockCard(_ block: TimeBlockImpact, maxBlock: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(block.label) Block")
                .font(.headline)
            Text(
                block.habitCount == 0
                    ? "No habits in this block"
                    : "\(block.habitCount) habit\(block.habitCount == 1 ? "" : "s") · all complete"
            )
            .font(.caption)
            .foregroundStyle(AppTheme.mutedText)
            if block.habitCount == 0 {
                Text("N/A").foregroundStyle(AppTheme.mutedText)
            } else if let avg = block.avgRating {
                Text("\(avg, specifier: "%.1f")")
                    .font(.stoic( 28, weight: .bold).monospacedDigit())
                + Text(" / 10").foregroundStyle(AppTheme.mutedText)
                ProgressView(value: avg / maxBlock)
                    .tint(AppTheme.blockAccent(block.category))
                Text("\(block.blockCompleteDays) of \(block.eligibleDays) rated days with full block")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Text("Not enough data").foregroundStyle(AppTheme.mutedText).font(.subheadline)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border.opacity(0.8), lineWidth: 2))
    }

    private func impactTable(_ rows: [HabitImpact]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Habit Impact Factor")
                .font(.headline)
            Text("Average day rating when completed vs missed. Higher impact means completing the habit correlates with a better day.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
            if rows.isEmpty {
                Text("Add habits and log a few days to see impact scores.")
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Habit").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                        Text("When done").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                        Text("When missed").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                        Text("Impact").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                        Text("Signal").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        GridRow {
                            HStack(spacing: 6) {
                                if index == 0 && row.hasEnoughData {
                                    Image(systemName: "sparkles").foregroundStyle(AppTheme.palette(.amber))
                                }
                                Text(row.title).font(.subheadline.weight(.medium))
                                categoryBadge(row.category)
                            }
                            Text(row.hasEnoughData ? format(row.avgRatingWhenCompleted) : "—")
                                .monospacedDigit()
                            Text(row.hasEnoughData ? format(row.avgRatingWhenMissed) : "—")
                                .monospacedDigit()
                            if row.hasEnoughData, let impact = row.impact {
                                Text("\(impact > 0 ? "+" : "")\(impact, specifier: "%.2f")")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(impact > 0 ? AppTheme.palette(.emerald) : (impact < 0 ? AppTheme.palette(.rose) : AppTheme.text))
                            } else {
                                Text("Not enough data").font(.caption).foregroundStyle(AppTheme.mutedText)
                            }
                            Text(Insights.impactLabel(row.impact))
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border.opacity(0.8), lineWidth: 2))
    }

    private func perfectDaysCard(_ data: InsightsPayload, perfectRate: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Perfect Days").font(.headline)
            Text("Days where every time block met its Perfect Day quota.")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
            Text("\(data.perfectDayCount)")
                .font(.stoic( 36, weight: .bold).monospacedDigit())
                .foregroundStyle(AppTheme.palette(.emerald))
            ProgressView(value: Double(perfectRate) / 100)
                .tint(AppTheme.palette(.emerald))
            Text("\(perfectRate)% of rated days (\(data.perfectDayCount) / \(data.totalLoggedDays))")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(16)
        .frame(maxWidth: 320, alignment: .leading)
        .background(AppTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.palette(.emerald).opacity(0.3), lineWidth: 2))
    }

    private func streaksTable(_ rows: [HabitStreakStats]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Streaks & Consistency").font(.headline)
            Text("Current streak counts through today if completed, otherwise through yesterday.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
            if rows.isEmpty {
                Text("No habits to track yet.")
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    GridRow {
                        Text("Habit").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                        Text("Current").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                        Text("Best").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                        Text("Status").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.mutedText)
                    }
                    ForEach(rows) { row in
                        GridRow {
                            HStack {
                                Text(row.title).font(.subheadline.weight(.medium))
                                categoryBadge(row.category)
                            }
                            Label("\(row.currentStreak)", systemImage: "flame.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Label("\(row.bestStreak)", systemImage: "trophy.fill")
                                .foregroundStyle(AppTheme.palette(.amber))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            if row.neverMissTwice {
                                Label("Never miss twice", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.palette(.amber).opacity(0.18), in: Capsule())
                                    .overlay(Capsule().stroke(AppTheme.palette(.amber).opacity(0.5)))
                            } else {
                                Text("").frame(width: 1)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border.opacity(0.8), lineWidth: 2))
    }

    private func categoryBadge(_ category: HabitCategory) -> some View {
        Text(category.rawValue)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.blockAccent(category).opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.blockAccent(category).opacity(0.35)))
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
}
