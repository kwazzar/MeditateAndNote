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
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var showNoteReminder: Bool {
        let todayActivity = streakTracker.activity(for: Date())
        return todayActivity.hasMeditation && !todayActivity.hasNote
    }

    var body: some View {
        VStack(spacing: 8) {
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

            if showNoteReminder {
                noteReminderBanner
            }
        }
    }

    // MARK: - Streak Number

    private var dayLabel: String {
        streakTracker.currentStreak == 1 ? "day" : "days"
    }

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

            Text(dayLabel)
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
                    isToday: Calendar.current.isDateInToday(day),
                    showPartialIndicatorForRecentDays: true,
                    onTap: {}
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Note Reminder

    private var noteReminderBanner: some View {
        Button(action: {
            router.navigate(to: .push(.newNote))
        }) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))

                Text("Write a note to complete today's streak")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.orange.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.snappy(duration: 0.3), value: showNoteReminder)
    }
}
