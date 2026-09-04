//
//  UserDefaultsReminderSettingsStore.swift
//  MeditateAndNote
//

import Foundation

/// Persists `ReminderSettings` in `UserDefaults`, mirroring the
/// `UserDefaultsStreakStore` / `SoundSettings` pattern.
final class UserDefaultsReminderSettingsStore: ReminderSettingsStore {
    private static let storageKey = "reminderSettings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReminderSettings {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .defaultValue
        }
        do {
            let box = try JSONDecoder().decode(CodableBox.self, from: data)
            return box.toSettings()
        } catch {
            return .defaultValue
        }
    }

    func save(_ settings: ReminderSettings) {
        guard let data = try? JSONEncoder().encode(CodableBox(from: settings)) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private extension UserDefaultsReminderSettingsStore {
    struct CodableBox: Codable {
        let isEnabled: Bool
        let hour: Int
        let minute: Int
        let weekdays: [Int]

        init(from settings: ReminderSettings) {
            self.isEnabled = settings.isEnabled
            self.hour = settings.hour
            self.minute = settings.minute
            self.weekdays = Array(settings.weekdays)
        }

        func toSettings() -> ReminderSettings {
            ReminderSettings(
                isEnabled: isEnabled,
                hour: hour,
                minute: minute,
                weekdays: Set(weekdays)
            )
        }
    }
}