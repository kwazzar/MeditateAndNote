//
//  StreakDayDetailSheet.swift
//  MeditateAndNote
//

import SwiftUI

struct StreakDayDetailSheet: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    let detail: StreakDayDetail
    let onMissingAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    stateSection
                    if hasTimestamps { timesSection }
                    if detail.missingAction != nil { missingActionSection }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(themeManager.current.mainBackground.ignoresSafeArea())
            .navigationTitle(detail.isToday ? "Today" : formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: detail.date)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: headerIcon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(accentColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(themeManager.current.textPrimary)

                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    private var stateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            stateRow(
                label: "Meditation",
                glyph: "M",
                isDone: detail.state == .complete || detail.state == .meditationOnly,
                color: themeManager.current.streakActiveMeditation
            )
            stateRow(
                label: "Note",
                glyph: "note.text",
                isDone: detail.state == .complete || detail.state == .noteOnly,
                color: themeManager.current.streakActiveNote
            )
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    private func stateRow(label: String, glyph: String, isDone: Bool, color: Color) -> some View {
        HStack(spacing: 10) {
            if glyph == "note.text" {
                Image(systemName: glyph)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDone ? color : themeManager.current.streakMuted)
                    .frame(width: 22)
            } else {
                Text(glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isDone ? color : themeManager.current.streakMuted)
                    .frame(width: 22)
            }

            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(themeManager.current.textPrimary)

            Spacer()

            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isDone ? color : themeManager.current.streakMuted)
        }
    }

    private var hasTimestamps: Bool {
        detail.meditationTime != nil || detail.noteTime != nil
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            if let meditationTime = detail.meditationTime {
                timeRow(label: "Meditation", time: meditationTime, color: themeManager.current.streakActiveMeditation)
            }
            if let noteTime = detail.noteTime {
                timeRow(label: "Note", time: noteTime, color: themeManager.current.streakActiveNote)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    private func timeRow(label: String, time: Date, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 22)

            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(themeManager.current.textPrimary)

            Spacer()

            Text(timeOfDayString(time))
                .font(.caption)
                .foregroundStyle(themeManager.current.textSecondary)
        }
    }

    private func timeOfDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var missingActionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(missingActionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            Text(missingActionMessage)
                .font(.caption)
                .foregroundStyle(themeManager.current.textSecondary)

            Button(action: {
                onMissingAction()
                dismiss()
            }) {
                HStack {
                    Image(systemName: missingActionIcon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(missingActionButtonTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.15))
                )
                .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    private var headerIcon: String {
        switch detail.state {
        case .complete: return "checkmark.seal.fill"
        case .meditationOnly: return "brain.head.profile"
        case .noteOnly: return "note.text"
        case .empty: return "moon.zzz.fill"
        }
    }

    private var accentColor: Color {
        switch detail.state {
        case .complete: return themeManager.current.streakSuccess
        case .meditationOnly: return themeManager.current.streakIndicator
        case .noteOnly: return themeManager.current.streakActiveNote
        case .empty: return themeManager.current.textSecondary
        }
    }

    private var headerTitle: String {
        switch detail.state {
        case .complete: return "Core Day complete"
        case .meditationOnly: return "Meditation done, note missing"
        case .noteOnly: return "Note written, meditation missing"
        case .empty: return "No activity"
        }
    }

    private var headerSubtitle: String {
        switch detail.state {
        case .complete:
            return "Both meditation and note are done — this day counts toward your streak."
        case .meditationOnly:
            return "Write a note today to complete the streak day."
        case .noteOnly:
            return "Meditate today to complete the streak day."
        case .empty:
            return "Neither a meditation nor a note was logged."
        }
    }

    private var missingActionTitle: String {
        switch detail.missingAction {
        case .meditation: return "Complete the day with meditation"
        case .note: return "Complete the day with a note"
        case .none: return ""
        }
    }

    private var missingActionMessage: String {
        switch detail.missingAction {
        case .meditation: return "A meditation is the missing half of this core day."
        case .note: return "A note is the missing half of this core day."
        case .none: return ""
        }
    }

    private var missingActionButtonTitle: String {
        switch detail.missingAction {
        case .meditation: return "Start meditation"
        case .note: return "Write note"
        case .none: return ""
        }
    }

    private var missingActionIcon: String {
        switch detail.missingAction {
        case .meditation: return "brain.head.profile"
        case .note: return "note.text"
        case .none: return "checkmark"
        }
    }
}