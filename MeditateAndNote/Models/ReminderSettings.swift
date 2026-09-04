//
//  ReminderSettings.swift
//  MeditateAndNote
//

import Foundation

// MARK: - ReminderSettingsStore (persistence boundary)

protocol ReminderSettingsStore {
    /// Loads the last saved settings, or the default when nothing is stored.
    func load() -> ReminderSettings
    /// Persists the settings.
    func save(_ settings: ReminderSettings)
}

// MARK: - ReminderSettings (Value Object)

/// Immutable preference describing when the app sends a local notification
/// reminding the user to meditate / write a note.
///
/// Invariants (enforced in `init`):
/// - `hour` is clamped to `0...23`
/// - `minute` is clamped to `0...59`
/// - `weekdays` is a non-empty subset of `1...7` (Calendar weekday:
///   1 = Sunday … 7 = Saturday)
struct ReminderSettings: Equatable {
    let isEnabled: Bool
    let hour: Int
    let minute: Int
    let weekdays: Set<Int>

    static let allWeekdays: ClosedRange<Int> = 1...7

    static var defaultValue: ReminderSettings {
        ReminderSettings(isEnabled: false, hour: 20, minute: 0, weekdays: Set(1...7))
    }

    init(isEnabled: Bool, hour: Int, minute: Int, weekdays: Set<Int>) {
        self.isEnabled = isEnabled
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)

        let valid = weekdays.filter { Self.allWeekdays.contains($0) }
        self.weekdays = valid.isEmpty ? Set([1]) : valid
    }

    /// Sorted weekday numbers (1 = Sunday … 7 = Saturday).
    var sortedWeekdays: [Int] {
        weekdays.sorted()
    }
}

// MARK: - ReminderScheduleBuilder (pure scheduling math)

/// Computes the concrete dates a weekly reminder should fire, starting after a
/// reference date. Pure domain logic — no `UNUserNotificationCenter` involved,
/// so it can be unit-tested cheaply.
struct ReminderScheduleBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Returns the next `count` fire dates strictly after `after`, restricted to
    /// `after`'s day boundary — i.e. if `hour:minute` today has not passed yet,
    /// today is included; otherwise scanning starts tomorrow.
    func nextFireDates(
        settings: ReminderSettings,
        after: Date,
        count: Int
    ) -> [Date] {
        guard settings.isEnabled, !settings.weekdays.isEmpty, count > 0 else { return [] }

        let components = calendar.dateComponents([.year, .month, .day], from: after)
        guard let startDay = calendar.date(from: components) else { return [] }

        var result: [Date] = []
        result.reserveCapacity(count)

        for offset in 0... {
            guard result.count < count else { break }
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { break }
            let weekday = calendar.component(.weekday, from: day)
            guard settings.weekdays.contains(weekday) else { continue }

            guard let slot = calendar.date(
                byAdding: DateComponents(hour: settings.hour, minute: settings.minute),
                to: day
            ) else { continue }

            if slot > after {
                result.append(slot)
            }
        }

        return result
    }
}