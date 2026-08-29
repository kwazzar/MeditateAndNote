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

    func testSave_thenSessionsForDate_returnsSession() async {
        let when = day(2026, 8, 20)
        let session = makeSession(completedAt: when)

        await sut.save(session)

        let result = await sut.sessions(for: when)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, session.id)
        XCTAssertEqual(result.first?.duration.seconds, 60)
    }

    func testSessionsForDate_returnsOnlyMatchingDay() async {
        let when = day(2026, 8, 20)
        let next = calendar.date(byAdding: .day, value: 1, to: when)!

        await sut.save(makeSession(completedAt: when, meditationID: "a"))
        await sut.save(makeSession(completedAt: next, meditationID: "b"))

        let result = await sut.sessions(for: when)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.meditationId.rawValue, "a")
    }

    func testSessionsForDate_ignoresTimeOfDay() async {
        let when = day(2026, 8, 20)
        let morning = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: when)!
        let evening = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: when)!

        await sut.save(makeSession(completedAt: morning, meditationID: "a"))
        await sut.save(makeSession(completedAt: evening, meditationID: "b"))

        let result = await sut.sessions(for: when)
        XCTAssertEqual(result.count, 2)
    }

    func testSessionsForDate_noSessions_returnsEmpty() async {
        let result = await sut.sessions(for: day(2026, 8, 20))
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - All session dates

    func testAllSessionDates_normalizesToStartOfDay() async {
        let when = day(2026, 8, 20)
        let next = calendar.date(byAdding: .day, value: 1, to: when)!

        await sut.save(makeSession(completedAt: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: when)!))
        await sut.save(makeSession(completedAt: calendar.date(bySettingHour: 21, minute: 15, second: 0, of: next)!))

        let result = await sut.allSessionDates()
        XCTAssertEqual(result, Set([when, next]))
    }

    func testAllSessionDates_emptyStore_isEmpty() async {
        let result = await sut.allSessionDates()
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Domain events

    func testHandle_meditationCompleted_savesSession() async {
        let when = day(2026, 8, 20)
        let session = makeSession(completedAt: when, meditationID: "5")

        await sut.handle(.meditationCompleted(session))

        let result = await sut.sessions(for: when)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.meditationId, session.meditationId)
    }
}