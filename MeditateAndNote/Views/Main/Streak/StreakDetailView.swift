//
//  StreakDetailView.swift
//  MeditateAndNote
//

import SwiftUI

struct StreakDetailView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StreakTracker.self) private var streakTracker
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    let insightsViewModel: InsightsViewModel

    @State private var selectedDayDetail: StreakDayDetail?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsHeader
                todayProgress
                InsightsSection(viewModel: insightsViewModel)
                LifetimePatternsSection(viewModel: insightsViewModel)
                calendarGrid
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(themeManager.current.mainBackground.ignoresSafeArea())
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $selectedDayDetail) { detail in
            StreakDayDetailSheet(
                detail: detail,
                onMissingAction: { handleMissingAction(detail.missingAction) }
            )
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            StatColumn(title: "Current", value: streakTracker.currentStreak, accent: true)
            Divider().frame(height: 40).foregroundStyle(themeManager.current.dividerColor)
            StatColumn(title: "Best", value: streakTracker.longestStreak, accent: false)
            Divider().frame(height: 40).foregroundStyle(themeManager.current.dividerColor)
            StatColumn(
                title: "Total",
                value: streakTracker.totalCompleteDays,
                accent: false
            )
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Today Progress (meditation first, then note)

    private var todayProgress: some View {
        let activity = streakTracker.activity(for: Date())
        let state = activity.coreDayState

        return VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            HStack(spacing: 16) {
                ProgressPill(
                    glyph: "M",
                    label: "Meditation",
                    isDone: activity.hasMeditation,
                    activeColor: themeManager.current.streakActiveMeditation,
                    onTap: state == .noteOnly ? { handleMissingAction(.meditation) } : nil
                )

                ProgressPill(
                    glyph: "note.text",
                    label: "Note",
                    isDone: activity.hasNote,
                    activeColor: themeManager.current.streakActiveNote,
                    onTap: state == .meditationOnly ? { handleMissingAction(.note) } : nil
                )

                Spacer()

                if state == .complete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(themeManager.current.streakSuccess)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if let hint = partialDayHint(for: state) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(themeManager.current.textSecondary)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .animation(.snappy, value: state)
    }

    private func partialDayHint(for state: CoreDayState) -> String? {
        switch state {
        case .meditationOnly: return "Tap the Note pill to write today's note and complete the day."
        case .noteOnly: return "Tap the Meditation pill to meditate and complete the day."
        case .complete, .empty: return nil
        }
    }

    private func handleMissingAction(_ action: StreakDayDetail.MissingAction?) {
        guard let action else { return }
        switch action {
        case .meditation:
            router.navigate(to: .tab(.meditations))
        case .note:
            router.navigate(to: .push(.newNote))
        }
    }

    // MARK: - Calendar Grid (current month, week rows)

    private var calendarGrid: some View {
        let weeks = buildMonthWeeks()

        return VStack(alignment: .leading, spacing: 16) {
            Text(monthTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            VStack(spacing: 8) {
                weekdayHeader
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    WeekRow(
                        days: weeks[weekIndex],
                        onSelect: { date in
                            selectedDayDetail = streakTracker.dayDetail(for: date)
                        }
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeManager.current.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + first) % symbols.count] }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func buildMonthWeeks() -> [[Date?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let monthStart = calendar.date(from: components) else { return [] }

        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let weekday = calendar.component(.weekday, from: monthStart)
        let startOffset = (weekday - calendar.firstWeekday + 7) % 7

        var allDays: [Date] = []
        for offset in (0..<(range.count + startOffset)).reversed() {
            if let date = calendar.date(byAdding: .day, value: -Int(offset), to: monthStart) {
                allDays.append(date)
            }
        }

        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: startOffset)

        for day in allDays {
            currentWeek.append(day)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 { currentWeek.append(nil) }
            weeks.append(currentWeek)
        }

        return weeks
    }
}

// MARK: - Stat Column

private struct StatColumn: View {
    @Environment(ThemeManager.self) private var themeManager
    let title: String
    let value: Int
    let accent: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(accent ? themeManager.current.streakIndicator : themeManager.current.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)

            Text(title)
                .font(.caption)
                .foregroundStyle(themeManager.current.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progress Pill

private struct ProgressPill: View {
    @Environment(ThemeManager.self) private var themeManager
    let glyph: String
    let label: String
    let isDone: Bool
    let activeColor: Color
    let onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            if glyph == "note.text" {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDone ? activeColor : themeManager.current.streakMuted)
            } else {
                Text(glyph)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDone ? activeColor : themeManager.current.streakMuted)
            }

            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDone ? activeColor : themeManager.current.streakMuted)

            Text(label)
                .font(.caption)
                .foregroundStyle(themeManager.current.textPrimary)

            if onTap != nil && !isDone {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(themeManager.current.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isDone ? activeColor.opacity(0.12) : themeManager.current.toolbarBackground)
        )
        .contentShape(Capsule())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Week Row

private struct WeekRow: View {
    @Environment(StreakTracker.self) private var streakTracker
    let days: [Date?]
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    let activity = streakTracker.activity(for: day)

                    DayCellView(
                        date: day,
                        hasMeditation: activity.hasMeditation,
                        hasNote: activity.hasNote,
                        isToday: Calendar.current.isDateInToday(day),
                        showPartialIndicatorForRecentDays: true,
                        onTap: { onSelect(day) }
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(width: 40)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Preview

struct StreakDetailView_Previews: PreviewProvider {
    static var previews: some View {
        StreakDetailView(
            insightsViewModel: InsightsViewModel(manager: PreviewInsightManager())
        )
        .environment(ThemeManager())
        .environment(StreakTracker())
        .environmentObject(Router.previewRouter())
    }
}

// MARK: - Preview double (avoids hand-built tracker wiring)

private final class PreviewInsightManager: StreakInsightProvidable {
    func insights(for range: StreakRange) -> [StreakInsight] { [] }
    func recommendations(for range: StreakRange) -> [UserRecommendation] { [] }
    func weeklyBreakdown(for range: StreakRange) -> [WeeklyBucket] { [] }
    func streakLengthDistribution() -> StreakLengthDistribution {
        .init(buckets: [], totalStreaks: 0, medianLength: 0)
    }
    func resilience() -> StreakResilience {
        .init(avgRecoveryDays: 0, longestRecoveryDays: 0, totalRecoveries: 0, survivalByDay: [:])
    }
    func weekdayBreakPattern() -> [Int: Double] { [:] }
    func weekdayBreakHeatmap() -> WeekdayHeatmapData { .init(days: []) }
}
