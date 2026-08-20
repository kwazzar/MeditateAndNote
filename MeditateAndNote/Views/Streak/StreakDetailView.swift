//
//  StreakDetailView.swift
//  MeditateAndNote
//

import SwiftUI

struct StreakDetailView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    let streakTracker: StreakTracker

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsHeader
                todayProgress
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
                value: streakTracker.dailyActivities.values.filter(\.isComplete).count,
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

        return VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            HStack(spacing: 16) {
                ProgressPill(
                    glyph: "M",
                    label: "Meditation",
                    isDone: activity.hasMeditation,
                    activeColor: themeManager.current.streakActiveMeditation
                )

                ProgressPill(
                    glyph: "note.text",
                    label: "Note",
                    isDone: activity.hasNote,
                    activeColor: themeManager.current.streakActiveNote
                )

                Spacer()

                if activity.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(themeManager.current.streakSuccess)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Calendar Grid (14 days, grouped by week)

    private var calendarGrid: some View {
        let weeks = buildWeeks(count: 14)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Last 2 Weeks")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            VStack(spacing: 8) {
                weekdayHeader
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    WeekRow(days: weeks[weekIndex], streakTracker: streakTracker)
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
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return (0..<7).map { symbols[($0 + first) % symbols.count] }
    }

    private func buildWeeks(count: Int) -> [[Date?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOffset = (weekday - calendar.firstWeekday + 7) % 7

        var allDays: [Date] = []
        for offset in (0..<(count + startOffset)).reversed() {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
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

        return Array(weeks.suffix(2))
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
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? Color.orange : themeManager.current.textPrimary)
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isDone ? activeColor.opacity(0.12) : themeManager.current.toolbarBackground)
        )
    }
}

// MARK: - Week Row

private struct WeekRow: View {
    let days: [Date?]
    let streakTracker: StreakTracker

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    let activity = streakTracker.activity(for: day)

                    DayCellView(
                        date: day,
                        hasMeditation: activity.hasMeditation,
                        hasNote: activity.hasNote,
                        isToday: Calendar.current.isDateInToday(day)
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    Color.clear.frame(width: 40)
                }
            }
        }
    }
}
