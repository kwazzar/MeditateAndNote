//
//  SemanticSearchManagerTests.swift
//  MeditateAndNoteTests
//
//  Ranking, laziness and availability of SemanticSearchManager.
//

import XCTest
@testable import MeditateAndNote

final class SemanticSearchManagerTests: XCTestCase {

    /// Deterministic token-space embedding: known words map to fixed basis
    /// vectors, unknown words hash into a slot (fixed dimension), and a text
    /// embeds as the normalized sum of its tokens — so shared words produce
    /// topical cosine overlap.
    private struct StubEmbeddingService: EmbeddingService {
        private static let dimension = 64

        var isAvailable: Bool
        var wordVectors: [String: [Float]] = [:]

        func embed(_ text: String) async throws -> [Float] {
            var output = [Float](repeating: 0, count: Self.dimension)
            for word in text.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let token = String(word)
                if let known = wordVectors[token] {
                    for i in known.indices where i < output.count {
                        output[i] += known[i]
                    }
                } else {
                    let slot = abs(token.hashValue) % Self.dimension
                    output[slot] += 1
                }
            }
            let length = sqrt(output.reduce(0) { $0 + $1 * $1 })
            return length > 0 ? output.map { $0 / length } : output
        }
    }

    private var store: InMemoryNoteEmbeddingStore!
    private var service: StubEmbeddingService!
    private var sut: SemanticSearchManager!

    override func setUp() {
        super.setUp()
        store = InMemoryNoteEmbeddingStore()
        service = StubEmbeddingService(isAvailable: true)
        sut = SemanticSearchManager(service: service, store: store)
    }

    override func tearDown() {
        store = nil
        service = nil
        sut = nil
        super.tearDown()
    }

    private func makeNote(_ title: String, _ content: String) -> Note {
        Note(title: NoteTitle(title), content: NoteContent(content))
    }

    // MARK: - Availability

    func testUnavailableService_returnsNoResults() async {
        service = StubEmbeddingService(isAvailable: false)
        sut = SemanticSearchManager(service: service, store: store)
        let note = makeNote("T", "animal")

        let results = await sut.search(
            matching: SemanticQuery(text: "animal", minSimilarity: 0),
            in: [note]
        )

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Ranking

    func testSearch_ranksByCosineSimilarityBestFirst() async {
        // One-hot basis per token: shared words overlap, distinct words don't.
        let service = StubEmbeddingService(
            isAvailable: true,
            wordVectors: [
                "feline": [1, 0, 0, 0, 0, 0, 0, 0],
                "meow": [0, 1, 0, 0, 0, 0, 0, 0],
                "whiskers": [0, 0, 1, 0, 0, 0, 0, 0],
                "canine": [0, 0, 0, 1, 0, 0, 0, 0],
                "bark": [0, 0, 0, 0, 1, 0, 0, 0],
                "tail": [0, 0, 0, 0, 0, 1, 0, 0],
                "cat": [0, 0, 0, 0, 0, 0, 1, 0],
                "dog": [0, 0, 0, 0, 0, 0, 0, 1],
            ]
        )
        sut = SemanticSearchManager(service: service, store: store)
        let cat = makeNote("Cat", "feline whiskers meow")
        let dog = makeNote("Dog", "canine bark tail")
        let notes = [dog, cat]

        let results = await sut.search(
            matching: SemanticQuery(text: "feline meow", minSimilarity: 0.2),
            in: notes
        )

        XCTAssertEqual(results.count, 1, "Only the topically-matching note clears the floor")
        XCTAssertEqual(results.first?.id, cat.id)
    }

    func testSearch_returnsAllMatchesAboveFloorOrderedByRelevance() async {
        // Redundant slots for the title tokens so no token falls back to hashing.
        let service = StubEmbeddingService(
            isAvailable: true,
            wordVectors: [
                "feline": [1, 0, 0, 0, 0, 0, 0, 0],
                "meow": [0, 1, 0, 0, 0, 0, 0, 0],
                "deep": [0, 0, 1, 0, 0, 0, 0, 0],
                "shallow": [0, 0, 0, 1, 0, 0, 0, 0],
                "unrelated": [0, 0, 0, 0, 1, 0, 0, 0],
                "shopping": [0, 0, 0, 0, 0, 1, 0, 0],
                "groceries": [0, 0, 0, 0, 0, 0, 1, 0],
                "list": [0, 0, 0, 0, 0, 0, 0, 1],
            ]
        )
        sut = SemanticSearchManager(service: service, store: store)
        // Deep repeats the query tokens (cos ≈ 0.94), shallow shares one
        // near-synonym token (cos ≈ 0.5), unrelated shares none.
        let deep = makeNote("Deep", "feline meow feline meow")
        let shallow = makeNote("Shallow", "feline")
        let unrelated = makeNote("Unrelated", "shopping groceries list")
        let notes = [shallow, unrelated, deep]

        let results = await sut.search(
            matching: SemanticQuery(text: "feline meow", minSimilarity: 0.2),
            in: notes
        )

        XCTAssertEqual(results.map(\.id), [deep.id, shallow.id])
    }

    func testSearch_emptyQuery_returnsNothing() async {
        let note = makeNote("Cat", "feline")
        let results = await sut.search(matching: SemanticQuery(text: "  "), in: [note])
        XCTAssertTrue(results.isEmpty)
    }

    func testSearch_respectsMinimumSimilarityFloor() async {
        let service = StubEmbeddingService(
            isAvailable: true,
            wordVectors: [
                "query": [1, 0, 0, 0, 0, 0],
                "match": [0.9, 0.1, 0, 0, 0, 0],
                "low": [0.4, 0.6, 0, 0, 0, 0],
            ]
        )
        sut = SemanticSearchManager(service: service, store: store)
        let match = makeNote("Match", "match")
        let low = makeNote("Low", "low")

        let results = await sut.search(
            matching: SemanticQuery(text: "query", minSimilarity: 0.8),
            in: [match, low]
        )

        XCTAssertEqual(results.map(\.id), [match.id])
    }

    // MARK: - Lazy embedding persistence

    func testEnsureEmbeddings_persistsNewNoteVectors() async throws {
        let note = makeNote("Cat", "feline meow")
        await sut.ensureEmbeddings(for: [note])

        let stored = try await store.fetch(noteID: note.id)
        XCTAssertNotNil(stored, "A missing embedding must be computed and saved")
    }

    func testEnsureEmbeddings_recomputesOnlyChangedNotes() async throws {
        let note = makeNote("Cat", "feline meow")
        await sut.ensureEmbeddings(for: [note])
        let original = try await store.fetch(noteID: note.id)

        // Wait a tick so updatedAt can differ if recomputed.
        try await Task.sleep(nanoseconds: 10_000_000)
        await sut.ensureEmbeddings(for: [note])

        let after = try await store.fetch(noteID: note.id)
        XCTAssertEqual(after?.updatedAt, original?.updatedAt,
                       "Unchanged note must not be re-embedded")
    }

    func testEnsureEmbeddings_skipsUnavailableService() async throws {
        service = StubEmbeddingService(isAvailable: false)
        sut = SemanticSearchManager(service: service, store: store)
        let note = makeNote("Cat", "feline")

        await sut.ensureEmbeddings(for: [note])

        let stored = try await store.fetch(noteID: note.id)
        XCTAssertNil(stored)
    }

    // MARK: - Cleanup

    func testDeleteEmbedding_removesRow() async throws {
        let note = makeNote("Cat", "feline")
        await sut.ensureEmbeddings(for: [note])
        let before = try await store.fetch(noteID: note.id)
        XCTAssertNotNil(before)

        await sut.deleteEmbedding(for: note.id)

        let after = try await store.fetch(noteID: note.id)
        XCTAssertNil(after)
    }

    // MARK: - NoteEmbedding invariants

    func testCosineSimilarity_matchesExpectedValues() {
        let e = { NoteEmbedding(noteID: NoteID(), vector: $0, contentHash: 0) }
        XCTAssertEqual(e([1, 0, 0]).cosineSimilarity(to: [1, 0, 0]), 1)
        XCTAssertEqual(e([1, 0, 0]).cosineSimilarity(to: [0, 1, 0]), 0)
        XCTAssertEqual(e([1, 0]).cosineSimilarity(to: [-1, 0]), -1)
        XCTAssertEqual(e([]).cosineSimilarity(to: []), 0)
    }

    func testContentHash_differsOnTextChange() {
        let a = NoteEmbedding.contentHash(title: "T", content: "one")
        let b = NoteEmbedding.contentHash(title: "T", content: "two")
        let same = NoteEmbedding.contentHash(title: "T", content: "one")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, same)
    }
}