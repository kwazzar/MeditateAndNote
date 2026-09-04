//
//  ReminderManager.swift
//  MeditateAndNote
//

import Foundation

// MARK: - Protocols

protocol ReminderProvidable {
    var settings: ReminderSettings { get }
    var isAuthorized: Bool { get }
    var authorizationRequested: Bool { get }
}

protocol ReminderManageable {
    func requestAuthorization() async -> Bool
    func enableReminder(hour: Int, minute: Int, weekdays: Set<Int>) async
    func disableReminder() async
    func updateSettings(_ settings: ReminderSettings) async
}

// MARK: - ReminderManager

/// Orchestrates reminder settings with local notification scheduling: every
/// settings mutation is persisted and reschedules the upcoming notifications.
@Observable
final class ReminderManager: ReminderProvidable, ReminderManageable {

    private(set) var settings: ReminderSettings
    private(set) var isAuthorized = false
    private(set) var authorizationRequested = false

    private let store: ReminderSettingsStore
    private let scheduler: NotificationScheduling
    private let builder: ReminderScheduleBuilder

    static let notificationTitle = "Streak reminder"
    static let notificationBody = "Time to complete today's streak — meditate and write a quick note."

    /// How many upcoming fire dates are scheduled ahead.
    static let schedulingHorizon = 7

    init(
        store: ReminderSettingsStore,
        scheduler: NotificationScheduling,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.scheduler = scheduler
        self.builder = ReminderScheduleBuilder(calendar: calendar)
        self.settings = store.load()
    }

    func refreshAuthorizationStatus() async {
        isAuthorized = await scheduler.isAuthorized()
    }

    func requestAuthorization() async -> Bool {
        authorizationRequested = true
        let granted = await scheduler.requestAuthorization()
        isAuthorized = granted
        return granted
    }

    func enableReminder(hour: Int, minute: Int, weekdays: Set<Int>) async {
        let granted = await requestAuthorization()
        guard granted else { return }
        await updateSettings(
            ReminderSettings(isEnabled: true, hour: hour, minute: minute, weekdays: weekdays)
        )
    }

    func disableReminder() async {
        await updateSettings(
            ReminderSettings(
                isEnabled: false,
                hour: settings.hour,
                minute: settings.minute,
                weekdays: settings.weekdays
            )
        )
    }

    func updateSettings(_ settings: ReminderSettings) async {
        self.settings = settings
        store.save(settings)
        await reschedule()
    }

    // MARK: - Private

    private func reschedule() async {
        scheduler.removeAllPendingNotifications()
        guard settings.isEnabled else { return }

        let fireDates = builder.nextFireDates(
            settings: settings,
            after: .now,
            count: Self.schedulingHorizon
        )

        for (index, date) in fireDates.enumerated() {
            scheduler.scheduleNotification(
                id: "streak-reminder-\(index)",
                title: Self.notificationTitle,
                body: Self.notificationBody,
                at: date
            )
        }
    }
}