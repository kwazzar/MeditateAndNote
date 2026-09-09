//
//  CoreDataNoteInsightStoreTests.swift
//  MeditateAndNoteTests
//
//  Round-trip persistence of NoteInsight through Core Data.
//

import XCTest
@testable import MeditateAndNote

final class CoreDataNoteInsightStoreTests: XCTestCase {

    private var manager: CoreDataManager!
    private var sut: CoreDataNoteInsightStore!

    override func setUp() {
        super.setUp()
        manager = CoreDataManager(inMemory: true)
        sut = CoreDataNoteInsightStore(manager: manager)
    }

    override func tearDown() {
        sut = nil
        manager = nil
        super.tearDown()
    }

    private func makeInsight(noteID: NoteID = NoteID(), summary: String = "summary") -> NoteInsight {
        NoteInsight(
            noteID: noteID,
            themes: [NoteTheme(label: "calm", relevance: 0.9)],
            summary: summary,
            suggestedTags: ["calm"]
        )
    }

    func testSaveThenFetch_roundTripsInsight() async throws {
        let insight = makeInsight()
        try await sut.save(insight)
        let fetched = try await sut.fetch(noteID: insight.noteID)
        XCTAssertEqual(fetched?.summary, insight.summary)
        XCTAssertEqual(fetched?.themes, insight.themes)
        XCTAssertEqual(fetched?.suggestedTags, insight.suggestedTags)
    }

    func testSaveTwice_sameNoteID_overwritesSingleRow() async throws {
        let noteID = NoteID()
        try await sut.save(makeInsight(noteID: noteID, summary: "old"))
        try await sut.save(makeInsight(noteID: noteID, summary: "new"))
        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.summary, "new")
    }

    func testDelete_removesRow() async throws {
        let insight = makeInsight()
        try await sut.save(insight)
        try await sut.delete(noteID: insight.noteID)
        let fetched = try await sut.fetch(noteID: insight.noteID)
        XCTAssertNil(fetched)
    }

    func testDeleteAll_clearsStore() async throws {
        try await sut.save(makeInsight())
        try await sut.save(makeInsight())
        try await sut.deleteAll()
        let all = try await sut.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }
}
