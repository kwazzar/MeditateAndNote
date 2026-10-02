//
//  NoteInsightsViewModelTests.swift
//  MeditateAndNoteTests
//
//  hasLoaded state for NoteInsightsViewModel.
//

import XCTest
@testable import MeditateAndNote

// MARK: - Stub provider

// ponytail: @unchecked — лічильник дзвінків живе в межах одного тесту,
// конкурентного доступу до нього немає.
private final class StubNoteInsightProvider: NoteInsightProvidable, @unchecked Sendable {
    var insightsResult: [NoteInsight] = []
    private(set) var fetchAllCallCount = 0

    func insights() async throws -> [NoteInsight] {
        fetchAllCallCount += 1
        return insightsResult
    }

    func insight(for noteID: NoteID) async throws -> NoteInsight? {
        insightsResult.first { $0.noteID == noteID }
    }
}

private final class StubNoteInsightManager: NoteInsightManageable {
    func refresh(notes: [Note]) async {}
    func deleteInsights(for noteID: NoteID) async {}
    func scheduleRefresh() async {}
    func refreshNow() async {}
}

private final class FailingNoteInsightProvider: NoteInsightProvidable, @unchecked Sendable {
    var fetchAllCallCount = 0

    func insights() async throws -> [NoteInsight] {
        fetchAllCallCount += 1
        throw NoteAnalysisError.insufficientData
    }

    func insight(for noteID: NoteID) async throws -> NoteInsight? {
        nil
    }
}

// MARK: - Tests

final class NoteInsightsViewModelTests: XCTestCase {

    private var store: InMemoryNoteInsightStore!
    private var bus: DomainEventBus!
    private var provider: StubNoteInsightProvider!
    private var manager: StubNoteInsightManager!

    override func setUp() {
        super.setUp()
        store = InMemoryNoteInsightStore()
        bus = DomainEventBus()
        provider = StubNoteInsightProvider()
        manager = StubNoteInsightManager()
    }

    override func tearDown() {
        store = nil
        bus = nil
        provider = nil
        manager = nil
        super.tearDown()
    }

    @MainActor
    private func makeVM() -> NoteInsightsViewModel {
        NoteInsightsViewModel(
            provider: provider,
            manager: manager,
            eventBus: bus
        )
    }

    // MARK: - hasLoaded

    @MainActor
    func testInit_hasLoadedIsFalse() throws {
        let vm = makeVM()
        XCTAssertFalse(vm.hasLoaded)
    }

    @MainActor
    func testLoad_setsHasLoadedTrueOnSuccess() async throws {
        provider.insightsResult = [
            NoteInsight(noteID: NoteID(), summary: "test")
        ]
        let vm = makeVM()

        await vm.load()

        XCTAssertTrue(vm.hasLoaded)
        XCTAssertEqual(provider.fetchAllCallCount, 1)
    }

    @MainActor
    func testLoad_setsHasLoadedTrueOnError() async throws {
        let vm = NoteInsightsViewModel(
            provider: FailingNoteInsightProvider(),
            manager: manager,
            eventBus: bus
        )

        await vm.load()

        XCTAssertTrue(vm.hasLoaded)
    }

    @MainActor
    func testLoad_calledTwiceWhenCalledTwice() async throws {
        provider.insightsResult = [
            NoteInsight(noteID: NoteID(), summary: "test")
        ]
        let vm = makeVM()

        await vm.load()
        XCTAssertEqual(provider.fetchAllCallCount, 1)
        await vm.load()
        XCTAssertEqual(provider.fetchAllCallCount, 2)
    }
}
