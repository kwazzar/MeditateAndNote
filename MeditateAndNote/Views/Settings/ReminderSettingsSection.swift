//
//  ReminderSettingsSection.swift
//  MeditateAndNote
//

import SwiftUI
import UIKit

struct ReminderSettingsSection: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openURL) private var openURL
    @Bindable var manager: ReminderManager

    @State private var weekdays: Set<Int> = Set(1...7)
    @State private var authorizationChecked = false

    private static let weekdaySymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: enabledBinding) {
                sectionHeader("Reminders", icon: "bell.badge.fill")
            }
            .tint(themeManager.current.streakActiveMeditation)

            if manager.settings.isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker("Reminder time", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .tint(themeManager.current.streakActiveMeditation)

                    Text("Repeat on")
                        .font(.subheadline)
                        .foregroundColor(themeManager.current.textSecondary)

                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { weekday in
                            weekdayChip(weekday)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundColor(themeManager.current.textPrimary)

                if authorizationChecked && !manager.isAuthorized {
                    authorizationBanner
                }
            }
        }
        .padding(20)
        .background(themeManager.current.editorBackground)
        .cornerRadius(16)
        .onAppear {
            syncWeekdaysFromSettings()
            Task {
                await manager.refreshAuthorizationStatus()
                authorizationChecked = true
            }
        }
    }

    // MARK: - Bindings

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { manager.settings.isEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        if !manager.isAuthorized {
                            let granted = await manager.requestAuthorization()
                            guard granted else { return }
                        }
                        await manager.updateSettings(currentDraftSettings())
                    }
                } else {
                    Task { await manager.disableReminder() }
                }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                return calendar.date(
                    bySettingHour: manager.settings.hour,
                    minute: manager.settings.minute,
                    second: 0,
                    of: .now
                ) ?? Date()
            },
            set: { newDate in
                let calendar = Calendar.current
                Task {
                    await manager.updateSettings(
                        ReminderSettings(
                            isEnabled: manager.settings.isEnabled,
                            hour: calendar.component(.hour, from: newDate),
                            minute: calendar.component(.minute, from: newDate),
                            weekdays: weekdays
                        )
                    )
                }
            }
        )
    }

    // MARK: - Pieces

    private func weekdayChip(_ weekday: Int) -> some View {
        let isSelected = weekdays.contains(weekday)
        return Button {
            if isSelected {
                guard weekdays.count > 1 else { return }
                weekdays.remove(weekday)
            } else {
                weekdays.insert(weekday)
            }
            guard manager.settings.isEnabled else { return }
            Task { await manager.updateSettings(currentDraftSettings()) }
        } label: {
            Text(Self.weekdaySymbols[weekday - 1])
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                              ? themeManager.current.streakActiveMeditation
                              : themeManager.current.toolbarBackground)
                )
                .foregroundColor(isSelected
                                 ? .white
                                 : themeManager.current.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var authorizationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 13))
                .foregroundColor(.orange)

            Text("Allow notifications to receive reminders")
                .font(.caption)
                .foregroundColor(themeManager.current.textSecondary)

            Spacer()

            Button("Allow") {
                Task {
                    let granted = await manager.requestAuthorization()
                    if granted {
                        await manager.updateSettings(currentDraftSettings())
                    } else if manager.authorizationRequested,
                              let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.current.streakActiveMeditation)
        }
    }

    // MARK: - Helpers

    private func currentDraftSettings() -> ReminderSettings {
        ReminderSettings(
            isEnabled: true,
            hour: manager.settings.hour,
            minute: manager.settings.minute,
            weekdays: weekdays
        )
    }

    private func syncWeekdaysFromSettings() {
        weekdays = manager.settings.weekdays
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.current.streakActiveMeditation)
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.current.textPrimary)
        }
    }
}