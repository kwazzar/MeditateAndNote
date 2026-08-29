//
//  CoreDataStreakStoreTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

final class CoreDataStreakStoreTests: XCTestCase {

    private let calendar = Calendar.current
    private var manager: CoreDataManager!
    private var sut: CoreDataStreakStore!

    override func setUp() {
        super.setUp()
        manager = CoreDataManager(inMemory: true)
        sut = CoreDataStreakStore(manager: manager)
    }

    override func tearDown() {
        sut = nil
        manager = nil
        super.tearDown()
    }

    private func day(_ offset: Int) -> Date {
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    private func activity(_ day: Date, meditation: Bool = false, note: Bool = false) -> DailyActivity {
        DailyActivity(date: day, hasMeditation: meditation, hasNote: note)
    }

    // MARK: - Empty store

    func testLoad_emptyStore_returnsNil() {
        XCTAssertNil(sut.load())
    }

    // MARK: - Save / Load round trip

    func testSaveThenLoad_roundTripsSnapshot() async {
        let day1 = day(0)
        let day2 = day(-1)
        let snapshot = StreakSnapshot(
            activities: [
                activity(day2, meditation: true, note: true),
                activity(day1, meditation: true, note: false),
            ],
            currentStreak: 3,
            longestStreak: 7,
            lastCountedDay: day1
        )

        await sut.save(snapshot)

        let loaded = sut.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(Set(loaded!.activities), Set(snapshot.activities))
        XCTAssertEqual(loaded!.currentStreak, 3)
        XCTAssertEqual(loaded!.longestStreak, 7)
        XCTAssertEqual(loaded!.lastCountedDay, day1)
    }

    // MARK: - Overwrite

    func testSaveTwice_replacesActivities() async {
        let first = StreakSnapshot(
            activities: [activity(day(0), meditation: true, note: true)],
            currentStreak: 2,
            longestStreak: 2,
            lastCountedDay: day(0)
        )
        await sut.save(first)

        let second = StreakSnapshot(
            activities: [activity(day(-1), meditation: true, note: true)],
            currentStreak: 1,
            longestStreak: 5,
            lastCountedDay: day(-1)
        )
        await sut.save(second)

        let loaded = sut.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded!.activities, second.activities, "Previous activity rows must be replaced, not appended")
        XCTAssertEqual(loaded!.currentStreak, 1)
        XCTAssertEqual(loaded!.longestStreak, 5)
    }

    func testSaveEmptyActivitiesWithValidCounters_returnsNonNilSnapshot() async {
        let snapshot = StreakSnapshot(
            activities: [],
            currentStreak: 4,
            longestStreak: 4,
            lastCountedDay: day(0)
        )

        await sut.save(snapshot)

        let loaded = sut.load()
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded!.activities.isEmpty)
        XCTAssertEqual(loaded!.currentStreak, 4)
    }

    // MARK: - Interplay with StreakTracker

    func testStreakTrackerWithCoreDataStore_fullFlow() async {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let tracker = StreakTracker(calendar: calendar, store: sut)

        await tracker.markNoteCreated(date: yesterday)
        await tracker.markMeditationCompleted(date: yesterday)
        await tracker.markNoteCreated(date: today)
        await tracker.markMeditationCompleted(date: today)

        XCTAssertEqual(tracker.currentStreak, 2)

        let reloaded = StreakTracker(calendar: calendar, store: CoreDataStreakStore(manager: manager))
        XCTAssertEqual(reloaded.currentStreak, 2, "Streak must persist through the Core Data store")
        XCTAssertTrue(reloaded.activity(for: today).isComplete)
        XCTAssertTrue(reloaded.activity(for: yesterday).isComplete)
    }
}