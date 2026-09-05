//
//  DayCellView.swift
//  MeditateAndNote
//

import SwiftUI

struct DayCellView: View {
    @Environment(ThemeManager.self) private var themeManager

    let date: Date
    let hasMeditation: Bool
    let hasNote: Bool
    let isToday: Bool
    /// When true, the cell shows its partial-state dot indicator for the
    /// past 7 days in addition to today, so the user can see where the
    /// streak was broken.
    let showPartialIndicatorForRecentDays: Bool
    let onTap: () -> Void

    private var state: CoreDayState {
        switch (hasMeditation, hasNote) {
        case (true, true): return .complete
        case (true, false): return .meditationOnly
        case (false, true): return .noteOnly
        case (false, false): return .empty
        }
    }

    /// Show the partial indicator for today, and (optionally) for any
    /// partial day in the recent past — that is the only signal that tells
    /// the user *where* the streak broke.
    private var shouldShowPartialIndicator: Bool {
        switch state {
        case .complete, .empty: return false
        case .meditationOnly, .noteOnly:
            if isToday { return true }
            return showPartialIndicatorForRecentDays
                && Calendar.current.isDate(date, equalTo: Date(), toGranularity: .day)
                == false
                && abs(date.timeIntervalSinceNow) <= 7 * 86_400
        }
    }

    private let cellSize: CGFloat = 32
    private let cornerRadius: CGFloat = 10

    private var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(2).capitalized
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(state == .complete ? themeManager.current.streakSuccess.opacity(0.15) : themeManager.current.streakCellBackground)
                    .frame(width: cellSize, height: cellSize)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: isToday ? 1.5 : 0.5)
                    .frame(width: cellSize, height: cellSize)

                ZStack {
                    HStack(spacing: 3) {
                        Text("M")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(hasMeditation ? themeManager.current.streakActiveMeditation : themeManager.current.streakMuted)

                        Image(systemName: "note.text")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(hasNote ? themeManager.current.streakActiveNote : themeManager.current.streakMuted)
                    }
                }
                .frame(width: cellSize, height: cellSize)

                if shouldShowPartialIndicator {
                    Circle()
                        .fill(partialIndicatorColor)
                        .frame(width: 6, height: 6)
                        .offset(x: 3, y: -3)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Text(weekdayLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(themeManager.current.textSecondary)
        }
        .frame(width: 40)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityLabel(accessibilityDescription)
    }

    private var borderColor: Color {
        if isToday {
            return state == .complete ? themeManager.current.streakSuccess : themeManager.current.streakActiveMeditation
        }
        return state == .complete ? themeManager.current.streakSuccess.opacity(0.5) : themeManager.current.dividerColor
    }

    private var partialIndicatorColor: Color {
        switch state {
        case .meditationOnly: return themeManager.current.streakIndicator
        case .noteOnly: return themeManager.current.streakActiveNote
        default: return .clear
        }
    }

    private var accessibilityDescription: String {
        switch state {
        case .complete: return "\(weekdayLabel): completed"
        case .meditationOnly: return "\(weekdayLabel): meditation done, note missing"
        case .noteOnly: return "\(weekdayLabel): note done, meditation missing"
        case .empty: return "\(weekdayLabel): no activity"
        }
    }
}
