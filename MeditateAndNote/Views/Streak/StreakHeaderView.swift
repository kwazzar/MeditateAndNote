//
//  StreakHeaderView.swift
//  MeditateAndNote
//

import SwiftUI

struct StreakHeaderView: View {
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject var router: Router
    let streakTracker: StreakTracker

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)!
        }
    }

    var body: some View {
        Button {
            router.navigate(to: .push(.streakDetail))
        } label: {
            HStack(spacing: 0) {
                streakNumberSection
                    .frame(minWidth: 72)

                Rectangle()
                    .fill(themeManager.current.dividerColor)
                    .frame(width: 0.5, height: 44)

                dayCellsSection
                    .padding(.leading, 12)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak Number

    private var streakNumberSection: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(streakTracker.isTodayComplete ? Color.orange : themeManager.current.textSecondary)

                Text("\(streakTracker.currentStreak)")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.current.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: streakTracker.currentStreak)
            }

            Text("днів")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeManager.current.textSecondary)
        }
    }

    // MARK: - 7 Day Cells

    private var dayCellsSection: some View {
        HStack(spacing: 0) {
            ForEach(last7Days, id: \.self) { day in
                let activity = streakTracker.activity(for: day)

                DayCellView(
                    date: day,
                    hasMeditation: activity.hasMeditation,
                    hasNote: activity.hasNote,
                    isToday: Calendar.current.isDateInToday(day)
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}
