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

    private var isComplete: Bool { hasMeditation && hasNote }

    private let cellSize: CGFloat = 32
    private let cornerRadius: CGFloat = 10

    private var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(2).capitalized
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isComplete ? themeManager.current.streakSuccess.opacity(0.15) : themeManager.current.streakCellBackground)
                    .frame(width: cellSize, height: cellSize)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isToday
                        ? (isComplete ? themeManager.current.streakSuccess : themeManager.current.streakActiveMeditation)
                        : (isComplete ? themeManager.current.streakSuccess.opacity(0.5) : themeManager.current.dividerColor),
                        lineWidth: isToday ? 1.5 : 0.5
                    )
                    .frame(width: cellSize, height: cellSize)

                HStack(spacing: 3) {
                    Text("M")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(hasMeditation ? themeManager.current.streakActiveMeditation : themeManager.current.streakMuted)

                    Image(systemName: "note.text")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(hasNote ? themeManager.current.streakActiveNote : themeManager.current.streakMuted)
                }
            }

            Text(weekdayLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(themeManager.current.textSecondary)
        }
        .frame(width: 40)
        .scaleEffect(isComplete ? 1.0 : 0.92)
        .animation(.snappy(duration: 0.2), value: isComplete)
    }
}
