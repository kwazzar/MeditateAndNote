//
//  ReminderManagerTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

private final class FakeScheduler: NotificationScheduling {
    var authorized = false
    var grantOnRequest = true
    private(set) var scheduled: [(id: String, date: Date)] = []
    private(set) var pendingRemovalCount = 0

    func isAuthorized() async -> Bool { authorized }

    func requestAuthorization() async -> Bool {
        authorized = grantOnRequest
        return grantOnRequest
    }

    func removeAllPendingNotifications() {
        pendingRemovalCount += 1
        scheduled.removeAll()
    }

    func scheduleNotification(id: String, title: String, body: String, at date: Date) {
        scheduled.append((id, date))
    }
}

final class ReminderManagerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: UserDefaultsReminderSettingsStore!
    private var scheduler: FakeScheduler!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ReminderManagerTests_\(UUID().uuidString)")!
        store = UserDefaultsReminderSettingsStore(defaults: defaults)
        scheduler = FakeScheduler()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
        super.tearDown()
    }

    private func makeSUT() -> ReminderManager {
        ReminderManager(store: store, scheduler: scheduler, calendar: calendar)
    }

    func testDefaults_whenNothingStored() async {
        let sut = makeSUT()
        XCTAssertFalse(sut.settings.isEnabled)
        XCTAssertEqual(sut.settings.hour, 20)
        XCTAssertEqual(sut.settings.weekdays, Set(1...7))
    }

    func testEnableReminder_granted_enablesAndSchedules() async {
        scheduler.grantOnRequest = true
        let sut = makeSUT()

        await sut.enableReminder(hour: 8, minute: 30, weekdays: Set([1]))

        XCTAssertTrue(sut.isAuthorized)
        XCTAssertTrue(sut.settings.isEnabled)
        XCTAssertEqual(sut.settings.hour, 8)
        XCTAssertEqual(sut.settings.minute, 30)
        XCTAssertEqual(sut.settings.weekdays, Set([1]))
        XCTAssertFalse(scheduler.scheduled.isEmpty)
    }

    func testEnableReminder_denied_leavesDisabled() async {
        scheduler.grantOnRequest = false
        let sut = makeSUT()

        await sut.enableReminder(hour: 8, minute: 30, weekdays: Set([1]))

        XCTAssertFalse(sut.isAuthorized)
        XCTAssertFalse(sut.settings.isEnabled)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    func testDisableReminder_clearsPending() async {
        scheduler.grantOnRequest = true
        let sut = makeSUT()

        await sut.enableReminder(hour: 8, minute: 0, weekdays: Set(1...7))
        let scheduledAfterEnable = scheduler.pendingRemovalCount
        XCTAssertGreaterThan(scheduler.scheduled.count, 0)

        await sut.disableReminder()

        XCTAssertFalse(sut.settings.isEnabled)
        XCTAssertEqual(scheduler.pendingRemovalCount, scheduledAfterEnable + 1)
        XCTAssertTrue(scheduler.scheduled.isEmpty, "No notifications remain after disable")
    }

    func testSettingsPersistAcrossInstances() async {
        scheduler.grantOnRequest = true
        let first = makeSUT()
        await first.enableReminder(hour: 21, minute: 45, weekdays: Set([6]))

        let second = makeSUT()
        XCTAssertTrue(second.settings.isEnabled)
        XCTAssertEqual(second.settings.hour, 21)
        XCTAssertEqual(second.settings.minute, 45)
        XCTAssertEqual(second.settings.weekdays, Set([6]))
    }

    func testUpdateSettings_reschedulesWithNewDraft() async {
        scheduler.grantOnRequest = true
        let sut = makeSUT()
        await sut.enableReminder(hour: 8, minute: 0, weekdays: Set(1...7))
        XCTAssertGreaterThan(scheduler.scheduled.count, 0)

        await sut.updateSettings(
            ReminderSettings(isEnabled: true, hour: 22, minute: 0, weekdays: Set([1]))
        )

        XCTAssertFalse(scheduler.scheduled.isEmpty)
        for entry in scheduler.scheduled {
            XCTAssertEqual(calendar.component(.hour, from: entry.date), 22)
            XCTAssertEqual(calendar.component(.weekday, from: entry.date), 1,
                           "Only Sunday slots must be scheduled")
            XCTAssertTrue(entry.date >= Date())
        }
    }
}