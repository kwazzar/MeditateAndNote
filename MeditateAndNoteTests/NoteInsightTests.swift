//
//  NoteInsightTests.swift
//  MeditateAndNoteTests
//
//  Domain invariants for the Sprint 3 insights aggregate.
//

import XCTest
@testable import MeditateAndNote

final class NoteInsightTests: XCTestCase {

    // MARK: - NoteTheme

    func testTheme_relevanceClampedToUnitInterval() {
        XCTAssertEqual(NoteTheme(label: "calm", relevance: 2).relevance, 1)
        XCTAssertEqual(NoteTheme(label: "calm", relevance: -1).relevance, 0)
        XCTAssertEqual(NoteTheme(label: "calm", relevance: .nan).relevance, 0)
    }

    func testTheme_labelTrimmed() {
        XCTAssertEqual(NoteTheme(label: "  calm  ", relevance: 0.5).label, "calm")
    }

    // MARK: - NoteInsight normalization

    func testInsight_capsThemesAtFive_sortedByRelevance() {
        let themes = (1...8).map { NoteTheme(label: "t\($0)", relevance: Double($0) / 10) }
        let insight = NoteInsight(noteID: NoteID(), themes: themes, summary: "s", suggestedTags: [])
        XCTAssertEqual(insight.themes.count, 5)
        XCTAssertEqual(insight.themes.first?.label, "t8")
    }

    func testInsight_dropsEmptyThemeLabels() {
        let insight = NoteInsight(
            noteID: NoteID(),
            themes: [NoteTheme(label: "  ", relevance: 1), NoteTheme(label: "calm", relevance: 0.5)],
            summary: "",
            suggestedTags: []
        )
        XCTAssertEqual(insight.themes.map(\.label), ["calm"])
    }

    func testInsight_tagsLowercasedDedupedAndCapped() {
        let insight = NoteInsight(
            noteID: NoteID(),
            summary: "",
            suggestedTags: ["Calm", " calm ", "", "SLEEP", "sleep", "a", "b", "c"]
        )
        XCTAssertEqual(insight.suggestedTags, ["calm", "sleep", "a", "b", "c"])
    }

    func testInsight_isEmpty_whenNoSignal() {
        XCTAssertTrue(NoteInsight(noteID: NoteID()).isEmpty)
        XCTAssertFalse(NoteInsight(noteID: NoteID(), summary: "x").isEmpty)
    }

    func testInsight_refreshed_preservesIdentity() {
        let noteID = NoteID()
        let insight = NoteInsight(noteID: noteID, summary: "old")
        let next = insight.refreshed(themes: [NoteTheme(label: "calm", relevance: 1)], summary: "new", suggestedTags: ["calm"])
        XCTAssertEqual(next.noteID, noteID)
        XCTAssertEqual(next.summary, "new")
        XCTAssertEqual(next.themes.map(\.label), ["calm"])
    }

    // MARK: - Collection invariant: max 1 insight per note

    func testCollection_upsertKeepsNewest() {
        var collection = NoteInsightsCollection()
        let noteID = NoteID()
        let old = NoteInsight(noteID: noteID, summary: "old", generatedAt: Date(timeIntervalSince1970: 100))
        let new = NoteInsight(noteID: noteID, summary: "new", generatedAt: Date(timeIntervalSince1970: 200))
        collection.upsert(old)
        collection.upsert(new)
        XCTAssertEqual(collection.count, 1)
        XCTAssertEqual(collection[noteID]?.summary, "new")
    }

    func testCollection_upsertIgnoresStaleWrite() {
        var collection = NoteInsightsCollection()
        let noteID = NoteID()
        collection.upsert(NoteInsight(noteID: noteID, summary: "new", generatedAt: Date(timeIntervalSince1970: 200)))
        collection.upsert(NoteInsight(noteID: noteID, summary: "stale", generatedAt: Date(timeIntervalSince1970: 100)))
        XCTAssertEqual(collection[noteID]?.summary, "new")
    }

    func testCollection_removeDropsNote() {
        var collection = NoteInsightsCollection()
        let noteID = NoteID()
        collection.upsert(NoteInsight(noteID: noteID, summary: "x"))
        collection.remove(noteID: noteID)
        XCTAssertNil(collection[noteID])
    }

    // MARK: - Heuristic analyzer

    func testHeuristic_emptyNotes_throwsInsufficientData() async {
        let analyzer = HeuristicNoteAnalyzer()
        await XCTAssertThrowsErrorType(
            try await analyzer.analyze(notes: []),
            NoteAnalysisError.insufficientData
        )
        await XCTAssertThrowsErrorType(
            try await analyzer.analyze(notes: [Note(title: "", content: "")]),
            NoteAnalysisError.insufficientData
        )
    }

    func testHeuristic_producesPerNoteInsights() async throws {
        let analyzer = HeuristicNoteAnalyzer()
        let notes = [
            Note(title: "Morning", content: "Morning meditation brought calm and calm focus"),
            Note(title: "", content: ""),
        ]
        let insights = try await analyzer.analyze(notes: notes)
        XCTAssertEqual(insights.count, 1, "Blank notes are skipped, not returned empty")
        XCTAssertFalse(insights[0].themes.isEmpty)
        XCTAssertFalse(insights[0].summary.isEmpty)
    }

    // MARK: - Helpers

    private func XCTAssertThrowsErrorType(
        _ expression: @autoclosure () async throws -> [NoteInsight],
        _ expected: NoteAnalysisError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as NoteAnalysisError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Wrong error type: \(error)", file: file, line: line)
        }
    }
}
