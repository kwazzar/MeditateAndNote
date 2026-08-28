//
//  CoreDataSessionStoreTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

final class CoreDataSessionStoreTests: XCTestCase {

    private let calendar = Calendar.current
    private var manager: CoreDataManager!
    private var sut: CoreDataSessionStore!

    override func setUp() {
        super.setUp()
        manager = CoreDataManager(inMemory: true)
        sut = CoreDataSessionStore(manager: manager)
    }

    override func tearDown() {
        sut = nil
        manager = nil
        super.tearDown()
    }

    func makeSession(completedAt: Date, meditationID: String = "1", seconds: TimeInterval = 60) -> MeditationSession {
        MeditationSession(
            meditationId: MeditationID(rawValue: meditationID),
            completedAt: completedAt,
            duration: SessionDuration(seconds: seconds)
        )
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)!
    }

    // MARK: - Save + fetch

    func testSave_thenSessionsForDate_returnsSession() {
        let when = day(2026, 8, 20)
        let session = makeSession(completedAt: when)

        sut.save(session)

        let result = sut.sessions(for: when)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, session.id)
        XCTAssertEqual(result.first?.duration.seconds, 60)
    }

    func testSessionsForDate_returnsOnlyMatchingDay() {
        let when = day(2026, 8, 20)
        let next = calendar.date(byAdding: .day, value: 1, to: when)!

        sut.save(makeSession(completedAt: when, meditationID: "a"))
        sut.save(makeSession(completedAt: next, meditationID: "b"))

        let result = sut.sessions(for: when)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.meditationId.rawValue, "a")
    }

    func testSessionsForDate_ignoresTimeOfDay() {
        let when = day(2026, 8, 20)
        let morning = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: when)!
        let evening = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: when)!

        sut.save(makeSession(completedAt: morning, meditationID: "a"))
        sut.save(makeSession(completedAt: evening, meditationID: "b"))

        XCTAssertEqual(sut.sessions(for: when).count, 2)
    }

    func testSessionsForDate_noSessions_returnsEmpty() {
        XCTAssertTrue(sut.sessions(for: day(2026, 8, 20)).isEmpty)
    }

    // MARK: - All session dates

    func testAllSessionDates_normalizesToStartOfDay() {
        let when = day(2026, 8, 20)
        let next = calendar.date(byAdding: .day, value: 1, to: when)!

        sut.save(makeSession(completedAt: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: when)!))
        sut.save(makeSession(completedAt: calendar.date(bySettingHour: 21, minute: 15, second: 0, of: next)!))

        XCTAssertEqual(sut.allSessionDates(), Set([when, next]))
    }

    func testAllSessionDates_emptyStore_isEmpty() {
        XCTAssertTrue(sut.allSessionDates().isEmpty)
    }

    // MARK: - Domain events

    func testHandle_meditationCompleted_savesSession() {
        let when = day(2026, 8, 20)
        let session = makeSession(completedAt: when, meditationID: "5")

        sut.handle(.meditationCompleted(session))

        let result = sut.sessions(for: when)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.meditationId, session.meditationId)
    }
}